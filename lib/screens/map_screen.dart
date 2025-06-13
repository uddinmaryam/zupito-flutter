import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:zupito/screens/qr_scanner_screen.dart';
import '../../models/bike.dart';
import 'dart:math';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LocationData? _currentLocation;
  final Location _location = Location();

  final List<Bike> _bikes = [
    Bike(
      id: 'B1',
      name: 'Zupito A',
      lat: 27.6775,
      lng: 85.3160,
      pricePerMinute: 2.0,
      isAvailable: true,
    ),
    Bike(
      id: 'B2',
      name: 'Zupito B',
      lat: 27.6760,
      lng: 85.3172,
      pricePerMinute: 1.5,
      isAvailable: false,
    ),
    Bike(
      id: 'B3',
      name: 'Zupito C',
      lat: 27.6748,
      lng: 85.3185,
      pricePerMinute: 1.8,
      isAvailable: true,
    ),
    Bike(
      id: 'B4',
      name: 'Zupito D',
      lat: 27.6783,
      lng: 85.3132,
      pricePerMinute: 2.2,
      isAvailable: false,
    ),
    Bike(
      id: 'B5',
      name: 'Zupito E',
      lat: 27.6722,
      lng: 85.3145,
      pricePerMinute: 1.7,
      isAvailable: true,
    ),
    Bike(
      id: 'B6',
      name: 'Zupito F',
      lat: 27.6798,
      lng: 85.3190,
      pricePerMinute: 2.1,
      isAvailable: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
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
    setState(() {
      _currentLocation = loc;
    });
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  void _showBikeDetails(Bike bike) {
    if (_currentLocation == null) return;
    final distance = calculateDistance(
      _currentLocation!.latitude!,
      _currentLocation!.longitude!,
      bike.lat,
      bike.lng,
    );

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "🚲 Bike: ${bike.name}",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text("🆔 ID: ${bike.id}"),
            Text(
              "💰 Price: Rs. ${bike.pricePerMinute.toStringAsFixed(2)} / minute",
            ),
            Text("📍 Distance: ${distance.toStringAsFixed(2)} km"),
            Text(
              bike.isAvailable
                  ? "✅ Status: Available"
                  : "❌ Status: Not Available",
              style: TextStyle(
                color: bike.isAvailable ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: bike.isAvailable
                    ? () {
                        Navigator.pop(context); // close bottom sheet
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const QRScannerScreen(),
                          ),
                        );
                      }
                    : null,
                child: const Text("Book a Ride"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng(27.6715, 85.3165);

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              center: center,
              zoom: 16.5,
              minZoom: 15.5,
              maxZoom: 18.0,
              maxBounds: LatLngBounds(
                LatLng(27.6690, 85.3080),
                LatLng(27.6840, 85.3260),
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 50,
                      height: 50,
                      point: LatLng(
                        _currentLocation!.latitude!,
                        _currentLocation!.longitude!,
                      ),
                      builder: (ctx) => const Icon(
                        Icons.person_pin_circle_rounded,
                        size: 50,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: _bikes.map((bike) {
                  return Marker(
                    width: 40,
                    height: 40,
                    point: LatLng(bike.lat, bike.lng),
                    builder: (ctx) => GestureDetector(
                      onTap: () => _showBikeDetails(bike),
                      child: Icon(
                        Icons.pedal_bike,
                        color: bike.isAvailable ? Colors.green: Colors.black,
                        size: 50,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          Positioned(
            top: 40,
            right: 20,
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white.withOpacity(0.9),
              child: IconButton(
                icon: const Icon(Icons.person, color: Colors.black),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile clicked')),
                  );
                },
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.orange,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QRScannerScreen(),
                  ),
                );
              },
              child: const Icon(Icons.qr_code_scanner),
            ),
          ),
        ],
      ),
    );
  }
}
