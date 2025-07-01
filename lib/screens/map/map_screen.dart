import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

import '../../models/station.dart';
import '../../models/user.dart';
import '../../../services/station_service.dart';
import '../../../services/secure_storage_services.dart';
import '../../../services/otp_socket_service.dart';
import 'widgets/station_bottom_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _currentLocation;
  final Location _location = Location();
  final MapController _mapController = MapController();
  Marker? _currentLocationMarker;
  final List<Station> _stations = [];
  final SecureStorageService _secureStorage = SecureStorageService();
  final List<LatLng> _routePoints = [];

  final List<LatLng> _lalitpurBoundary = [
    LatLng(27.6912, 85.3127),
    LatLng(27.6815, 85.3293),
    LatLng(27.6677, 85.3324),
    LatLng(27.6545, 85.3178),
    LatLng(27.6619, 85.2952),
    LatLng(27.6804, 85.2918),
    LatLng(27.6901, 85.2991),
  ];

  UserProfile? _userProfile;

  bool isInsideLalitpur(LatLng point) {
    bool inside = false;
    for (int i = 0, j = _lalitpurBoundary.length - 1; i < _lalitpurBoundary.length; j = i++) {
      if (((_lalitpurBoundary[i].latitude > point.latitude) !=
              (_lalitpurBoundary[j].latitude > point.latitude)) &&
          (point.longitude <
              (_lalitpurBoundary[j].longitude - _lalitpurBoundary[i].longitude) *
                      (point.latitude - _lalitpurBoundary[i].latitude) /
                      (_lalitpurBoundary[j].latitude - _lalitpurBoundary[i].latitude) +
                  _lalitpurBoundary[i].longitude)) {
        inside = !inside;
      }
    }
    return inside;
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadUserProfile();
    _loadStations();
  }

  Future<void> _loadUserProfile() async {
    final userData = await _secureStorage.readUser();
    if (userData != null) {
      final json = jsonDecode(userData);
      final user = UserProfile.fromJson(json);
      setState(() {
        _userProfile = user;
      });
      OtpSocketService().connect(user.id, context: context);
    }
  }

  Future<void> _loadStations() async {
    try {
      final stations = await StationService.fetchStations();
      setState(() {
        _stations.clear();
        _stations.addAll(stations);
      });
    } catch (e) {
      debugPrint('❌ Error fetching stations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching stations: $e')),
        );
      }
    }
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) serviceEnabled = await _location.requestService();
    if (!serviceEnabled) return;

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    final loc = await _location.getLocation();
    if (loc.latitude != null && loc.longitude != null) {
      final newLocation = LatLng(loc.latitude!, loc.longitude!);
      setState(() {
        _currentLocation = newLocation;
        _currentLocationMarker = Marker(
          point: newLocation,
          width: 60,
          height: 60,
          child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 36),
        );
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(newLocation, 15);
      });
    }

    _location.onLocationChanged.listen((loc) {
      if (loc.latitude != null && loc.longitude != null) {
        final updatedLocation = LatLng(loc.latitude!, loc.longitude!);
        setState(() {
          _currentLocation = updatedLocation;
          _currentLocationMarker = Marker(
            point: updatedLocation,
            width: 60,
            height: 60,
            child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 36),
          );
        });

        if (!isInsideLalitpur(updatedLocation)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ You are outside the allowed area!'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    });
  }

  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final coords = data['routes'][0]['geometry']['coordinates'];
      final points = coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();

      setState(() {
        _routePoints.clear();
        _routePoints.addAll(points);
      });
    } else {
      debugPrint('❌ Failed to fetch route: ${response.body}');
    }
  }

  void _onStationTap(Station station) async {
    if (_userProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in.")),
      );
      return;
    }

    final LatLng? result = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: buildStationBottomSheet(
          context,
          station,
          _userProfile!,
          onUnlockSuccess: (LatLng bikeLocation) {
            if (_currentLocation != null) {
              _fetchRoute(_currentLocation!, bikeLocation);
            }
          },
        ),
      ),
    );

    if (result != null && _currentLocation != null) {
      _fetchRoute(_currentLocation!, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8F0FE),
        elevation: 0,
        title: const Text(
          "Explore Zupito Rides",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
      body: _currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(center: _currentLocation, zoom: 15),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _lalitpurBoundary + [_lalitpurBoundary[0]],
                      strokeWidth: 2.5,
                      color: Colors.red,
                      isDotted: true,
                    ),
                    if (_routePoints.isNotEmpty)
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 4.0,
                        color: Colors.indigo,
                      ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    ..._stations.map(
                      (station) => Marker(
                        point: LatLng(station.lat, station.lng),
                        width: 60,
                        height: 60,
                        child: GestureDetector(
                          onTap: () => _onStationTap(station),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.indigo,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                    if (_currentLocationMarker != null) _currentLocationMarker!,
                  ],
                ),
              ],
            ),
    );
  }
}
