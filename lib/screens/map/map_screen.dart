import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:zupito/screens/map/widgets/user_profile_modal.dart';
import 'package:zupito/screens/map/widgets/user_profile_panel.dart';

import '../../models/station.dart';
import '../../models/user.dart';
import '../../../services/ride_service.dart';
import '../../../services/station_service.dart';

import 'widgets/station_marker.dart';
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
  List<LatLng> pathPoints = [];
  List<Station> _stations = [];

  final UserProfile _userProfile = UserProfile(
    id: '123',
    name: 'Maryam Uddin',
    email: 'maryam@example.com',
    walletBalance: 250.0,
    totalRides: 12,
    totalDistance: 35.7,
    membershipLevel: 'Premium',
    joinedDate: DateTime(2024, 5, 10),
  );

  final List<LatLng> _lalitpurBoundary = [
    LatLng(27.6912, 85.3127),
    LatLng(27.6815, 85.3293),
    LatLng(27.6677, 85.3324),
    LatLng(27.6545, 85.3178),
    LatLng(27.6619, 85.2952),
    LatLng(27.6804, 85.2918),
    LatLng(27.6901, 85.2991),
  ];

  bool isInsideLalitpur(LatLng point) {
    int i = 0, j = _lalitpurBoundary.length - 1;
    bool inside = false;
    for (; i < _lalitpurBoundary.length; j = i++) {
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
    _loadStations();
  }

  Future<void> _loadStations() async {
    try {
      final stations = await StationService.fetchStations();
      setState(() {
        _stations.clear();
        _stations.addAll(stations);
      });
      if (_stations.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(LatLng(_stations[0].lat, _stations[0].lng), 16);
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching stations: $e');
    }
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

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
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 32),
          ),
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
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 32),
            ),
          );
        });

        if (!isInsideLalitpur(updatedLocation)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ You are outside the allowed area!'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      }
    });
  }

  void _showStationDetails(Station station) {
    if (_currentLocation == null) return;

    drawRoute(context, _currentLocation!, LatLng(station.lat, station.lng), (
      routePoints,
    ) {
      setState(() => pathPoints = routePoints);
      _mapController.move(LatLng(station.lat, station.lng), 16);
    });

    showStationBottomSheet(context, station, _userProfile);
  }

  void _showUserProfile() => showUserProfilePanel(context, _userProfile);

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
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.black87),
            onPressed: _showUserProfile,
          ),
        ],
      ),
      body: _currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(center: _currentLocation, zoom: 15),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: ['a', 'b', 'c'],
                    ),
                    PolygonLayer(
                      polygons: [
                        Polygon(
                          points: _lalitpurBoundary,
                          color: Colors.green.withOpacity(0.2),
                          borderStrokeWidth: 3.0,
                          borderColor: Colors.red,
                        ),
                      ],
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: pathPoints,
                          color: Colors.red,
                          strokeWidth: 4.0,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        ..._stations.map(
                          (station) => StationMarker(
                            station: station,
                            onTap: () => _showStationDetails(station),
                          ).marker,
                        ),
                        if (_currentLocationMarker != null) _currentLocationMarker!,
                      ],
                    ),
                  ],
                ),
                Positioned(
                  bottom: 80,
                  right: 10,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        mini: true,
                        onPressed: () {
                          final zoom = _mapController.zoom + 1;
                          _mapController.move(_mapController.center, zoom);
                        },
                        child: const Icon(Icons.zoom_in),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        mini: true,
                        onPressed: () {
                          final zoom = _mapController.zoom - 1;
                          _mapController.move(_mapController.center, zoom);
                        },
                        child: const Icon(Icons.zoom_out),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        onPressed: _initLocation,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}
