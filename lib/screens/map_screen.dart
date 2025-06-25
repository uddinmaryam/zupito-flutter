// Complete MapScreen with backend-based unlock, route drawing, and real fare calculation

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

class Bike {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double pricePerMinute;
  final bool isAvailable;
  final int? availableInMinutes;

  Bike({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.pricePerMinute,
    required this.isAvailable,
    this.availableInMinutes,
  });

  String get code => id;
}

class Station {
  final String name;
  final String description;
  final double lat;
  final double lng;
  final List<Bike> bikes;

  Station({
    required this.name,
    required this.description,
    required this.lat,
    required this.lng,
    required this.bikes,
  });
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _currentLocation;
  final Location _location = Location();
  List<LatLng> pathPoints = [];
  final MapController _mapController = MapController();
  Marker? _currentLocationMarker;

  final List<Station> _stations = [
    Station(
      name: 'Sanepa',
      description: 'Popular spot in Sanepa area.',
      lat: 27.685353,
      lng: 85.307080,
      bikes: [
        Bike(id: 'S1', name: 'Sanepa Bike 1', lat: 27.685353, lng: 85.307080, pricePerMinute: 2.0, isAvailable: true),
        Bike(id: 'S2', name: 'Sanepa Bike 2', lat: 27.685400, lng: 85.307100, pricePerMinute: 2.0, isAvailable: false, availableInMinutes: 4),
        Bike(id: 'S3', name: 'Sanepa Bike 3', lat: 27.685400, lng: 85.307100, pricePerMinute: 2.0, isAvailable: true),
      ],
    ),
    Station(
      name: 'Pulchowk',
      description: 'Near Pulchowk campus area.',
      lat: 27.679600,
      lng: 85.319458,
      bikes: [
        Bike(id: 'P1', name: 'Pulchowk Bike 1', lat: 27.679600, lng: 85.319458, pricePerMinute: 2.2, isAvailable: true),
        Bike(id: 'P2', name: 'Pulchowk Bike 2', lat: 27.679650, lng: 85.319500, pricePerMinute: 2.2, isAvailable: true),
        Bike(id: 'P3', name: 'Pulchowk Bike 3', lat: 27.679650, lng: 85.319500, pricePerMinute: 2.2, isAvailable: true),
      ],
    ),
    Station(
      name: 'Jawalakhel',
      description: 'Close to Jawalakhel area.',
      lat: 27.673389,
      lng: 85.312648,
      bikes: [
        Bike(id: 'J1', name: 'Jawalakhel Bike 1', lat: 27.673389, lng: 85.312648, pricePerMinute: 1.8, isAvailable: true),
        Bike(id: 'J2', name: 'Jawalakhel Bike 2', lat: 27.673450, lng: 85.312700, pricePerMinute: 1.8, isAvailable: false, availableInMinutes: 6),
        Bike(id: 'J3', name: 'Jawalakhel Bike 3', lat: 27.673450, lng: 85.312700, pricePerMinute: 1.8, isAvailable: true),
      ],
    ),
  ];

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

  Future<List<LatLng>> fetchRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final coords = data['routes'][0]['geometry']['coordinates'] as List;
      return coords.map<LatLng>((p) => LatLng(p[1], p[0])).toList();
    } else {
      throw Exception('Failed to fetch route');
    }
  }

  void _drawRouteToStation(LatLng destination) async {
    if (_currentLocation != null) {
      try {
        final route = await fetchRoute(_currentLocation!, destination);
        setState(() => pathPoints = route);
        _mapController.move(destination, 16);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error drawing route: $e')));
      }
    }
  }

  void _showStationDetails(Station station) {
    _drawRouteToStation(LatLng(station.lat, station.lng));

    final availableBikes = station.bikes.where((b) => b.isAvailable).toList();
    final unavailableBikes = station.bikes.where((b) => !b.isAvailable).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        maxChildSize: 0.75,
        minChildSize: 0.3,
        initialChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                station.name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(station.description),
              const SizedBox(height: 16),
              Text('Available Bikes (${availableBikes.length})'),
              const SizedBox(height: 12),
              if (availableBikes.isEmpty)
                const Center(child: Text('No bikes available.'))
              else
                ...availableBikes.map(
                  (bike) => Card(
                    child: ListTile(
                      title: Text(bike.name),
                      subtitle: Text('Rs. ${bike.pricePerMinute}/min'),
                      trailing: ElevatedButton(
                        onPressed: () => _unlockBike(bike),
                        child: const Text('Unlock'),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text('Unavailable Bikes (${unavailableBikes.length})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 12),
              if (unavailableBikes.isEmpty)
                const Center(child: Text('No unavailable bikes.'))
              else
                ...unavailableBikes.map(
                  (bike) => Card(
                    color: Colors.grey[200],
                    child: ListTile(
                      title: Text(bike.name),
                      subtitle: Text('Available in ${bike.availableInMinutes ?? '?'} mins'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _unlockBike(Bike bike) async {
    final now = DateTime.now();
    final unlockUrl = Uri.parse('https://backend-bicycle.onrender.com/api/v1/bikes/${bike.id}/unlock');

    try {
      final response = await http.post(unlockUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final startTime = DateTime.parse(data['startTime']);

        await Future.delayed(const Duration(seconds: 5));

        final endTime = DateTime.now();
        final stopUrl = Uri.parse('https://backend-bicycle.onrender.com/api/v1/bikes/${bike.id}/stop');

        final stopResponse = await http.post(
          stopUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'endTime': endTime.toIso8601String()}),
        );

        if (stopResponse.statusCode == 200) {
          final fareData = jsonDecode(stopResponse.body);
          final fare = fareData['fare'];

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Ride Completed'),
              content: Text('Total fare: Rs. ${fare.toStringAsFixed(2)}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        } else {
          throw Exception('Failed to end ride');
        }
      } else {
        throw Exception('Unlock failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bike Stations Map")),
      body: _currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(center: _currentLocation, zoom: 15),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                      (station) => Marker(
                        point: LatLng(station.lat, station.lng),
                        width: 80,
                        height: 80,
                        child: IconButton(
                          icon: const Icon(Icons.location_on, color: Colors.black, size: 35),
                          onPressed: () => _showStationDetails(station),
                        ),
                      ),
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
