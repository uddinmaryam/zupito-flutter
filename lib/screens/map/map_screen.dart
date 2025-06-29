import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import '../../models/station.dart';
import '../../../services/station_service.dart';

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
    bool inside = false;
    for (
      int i = 0, j = _lalitpurBoundary.length - 1;
      i < _lalitpurBoundary.length;
      j = i++
    ) {
      if (((_lalitpurBoundary[i].latitude > point.latitude) !=
              (_lalitpurBoundary[j].latitude > point.latitude)) &&
          (point.longitude <
              (_lalitpurBoundary[j].longitude -
                          _lalitpurBoundary[i].longitude) *
                      (point.latitude - _lalitpurBoundary[i].latitude) /
                      (_lalitpurBoundary[j].latitude -
                          _lalitpurBoundary[i].latitude) +
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
      print('✅ STATIONS FETCHED: ${stations.length}');
      for (var s in stations) {
        print('📍 ${s.name} → (${s.lat}, ${s.lng})');
      }
      setState(() {
        _stations.clear();
        _stations.addAll(stations);
      });

      if (stations.isEmpty && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No stations found')));
      }
    } catch (e) {
      debugPrint('❌ Error fetching stations: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching stations: $e')));
      }
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
            child: const Icon(
              Icons.person_pin_circle,
              color: Colors.white,
              size: 32,
            ),
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
              child: const Icon(
                Icons.person_pin_circle,
                color: Colors.white,
                size: 32,
              ),
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
                  ],
                ),
                MarkerLayer(
                  markers: [
                    ..._stations.map(
                      (station) => Marker(
                        point: LatLng(station.lat, station.lng),
                        width: 60,
                        height: 60,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
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
