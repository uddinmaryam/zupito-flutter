import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

import '../../models/station.dart';
import '../../models/user.dart';
import '../../../services/ride_service.dart';
import '../../../services/station_service.dart';

import 'widgets/station_marker.dart';
import 'widgets/station_bottom_sheet.dart';
import 'widgets/user_profile_modal.dart';
import '../../../services/ride_service.dart';


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

  final List<Station> _stations = []; // Load from backend or static file
  final UserProfile _userProfile = UserProfile();

  @override
  void initState() {
    super.initState();
    _initLocation();
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
          width: 50,
          height: 50,
          child: const Icon(Icons.my_location, color: Colors.blue, size: 40),
        );
      });
      _mapController.move(newLocation, 15);
    }

    _location.onLocationChanged.listen((loc) {
      if (loc.latitude != null && loc.longitude != null) {
        final updatedLocation = LatLng(loc.latitude!, loc.longitude!);
        setState(() {
          _currentLocation = updatedLocation;
          _currentLocationMarker = Marker(
            point: updatedLocation,
            width: 50,
            height: 50,
            child: const Icon(Icons.my_location, color: Colors.blue, size: 40),
          );
        });
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

  void _showUserProfile() => showUserProfileModal(context, _userProfile);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bike Stations Map"),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: _showUserProfile,
          ),
        ],
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
                  subdomains: ['a', 'b', 'c'],
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: pathPoints,
                      color: Colors.blue,
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
      floatingActionButton: FloatingActionButton(
        onPressed: _initLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
