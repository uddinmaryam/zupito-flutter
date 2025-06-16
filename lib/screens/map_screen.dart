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

  final Map<String, LatLng> stationCoordinates = {
    'sanepa': LatLng(27.685353, 85.307080),
    'pulchowk': LatLng(27.679600, 85.319458),
    'jawalakhel': LatLng(27.673389, 85.312648),
  };

  final List<Station> _stations = [
    Station(
      name: 'Sanepa',
      description: 'Popular spot in Sanepa area.',
      lat: 27.685353,
      lng: 85.307080,
      bikes: [
        Bike(
          id: 'S1',
          name: 'Sanepa Bike 1',
          lat: 27.685353,
          lng: 85.307080,
          pricePerMinute: 2.0,
          isAvailable: true,
        ),
        Bike(
          id: 'S2',
          name: 'Sanepa Bike 2',
          lat: 27.685400,
          lng: 85.307100,
          pricePerMinute: 2.0,
          isAvailable: false,
          availableInMinutes: 4,
        ),
        Bike(
          id: 'S3',
          name: 'Sanepa Bike 3',
          lat: 27.685400,
          lng: 85.307100,
          pricePerMinute: 2.0,
          isAvailable: true,
        ),
      ],
    ),
    Station(
      name: 'Pulchowk',
      description: 'Near Pulchowk campus area.',
      lat: 27.679600,
      lng: 85.319458,
      bikes: [
        Bike(
          id: 'P1',
          name: 'Pulchowk Bike 1',
          lat: 27.679600,
          lng: 85.319458,
          pricePerMinute: 2.2,
          isAvailable: true,
        ),
        Bike(
          id: 'P2',
          name: 'Pulchowk Bike 2',
          lat: 27.679650,
          lng: 85.319500,
          pricePerMinute: 2.2,
          isAvailable: true,
        ),
        Bike(
          id: 'P3',
          name: 'Pulchowk Bike 3',
          lat: 27.679650,
          lng: 85.319500,
          pricePerMinute: 2.2,
          isAvailable: true,
        ),
      ],
    ),
    Station(
      name: 'Jawalakhel',
      description: 'Close to Jawalakhel area.',
      lat: 27.673389,
      lng: 85.312648,
      bikes: [
        Bike(
          id: 'J1',
          name: 'Jawalakhel Bike 1',
          lat: 27.673389,
          lng: 85.312648,
          pricePerMinute: 1.8,
          isAvailable: true,
        ),
        Bike(
          id: 'J2',
          name: 'Jawalakhel Bike 2',
          lat: 27.673450,
          lng: 85.312700,
          pricePerMinute: 1.8,
          isAvailable: false,
          availableInMinutes: 6,
        ),
        Bike(
          id: 'J3',
          name: 'Jawalakhel Bike 3',
          lat: 27.673450,
          lng: 85.312700,
          pricePerMinute: 1.8,
          isAvailable: true,
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    // Check if location service is enabled
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
        return;
      }
    }

    // Check location permission
    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }
    }

    // Get current location once
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

      _mapController.move(newLocation, 15); // Move to current location
    }

    // Listen for location updates
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

        // Optionally move camera
        //_mapController.move(updatedLocation, 15);
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

      // Extract coordinates from OSRM response: data['routes'][0]['geometry']['coordinates']
      final coords = data['routes'][0]['geometry']['coordinates'] as List;

      return coords.map<LatLng>((point) => LatLng(point[1], point[0])).toList();
    } else {
      throw Exception('Failed to fetch route: ${response.statusCode}');
    }
  }

  double _degToRad(double degree) => degree * pi / 180;

  double calculateDistanceInKm(LatLng start, LatLng end) {
    const double R = 6371;
    final dLat = _degToRad(end.latitude - start.latitude);
    final dLon = _degToRad(end.longitude - start.longitude);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(start.latitude)) *
            cos(_degToRad(end.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  void _showStationDetails(Station station) {
    final availableBikes = station.bikes.where((b) => b.isAvailable).toList();
    final unavailableBikes = station.bikes
        .where((b) => !b.isAvailable)
        .toList();

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
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                station.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
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
                      leading: const Icon(
                        Icons.pedal_bike,
                        color: Colors.green,
                      ),
                      title: Text(bike.name),
                      subtitle: Text(
                        'Rs. ${bike.pricePerMinute.toStringAsFixed(2)}/min',
                      ),
                      trailing: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showBikeDetails(bike);
                        },
                        child: const Text('Unlock'),
                      ),
                    ),
                  ),
                ),
              // Unavailable bikes section
              Text(
                'Unavailable Bikes (${unavailableBikes.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 12),
              if (unavailableBikes.isEmpty)
                const Center(child: Text('No unavailable bikes.'))
              else
                ...unavailableBikes.map(
                  (bike) => Card(
                    color: Colors.grey[200],
                    child: ListTile(
                      leading: const Icon(Icons.pedal_bike, color: Colors.grey),
                      title: Text(bike.name),
                      subtitle: Text(
                        'Unavailable - Available in ${bike.availableInMinutes ?? '?'} mins',
                        style: const TextStyle(color: Colors.red),
                      ),
                      trailing: const Text(''),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBikeDetails(Bike bike) {
    bool isUnlocked = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(bike.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bike ID: ${bike.id}'),
              Text('Price: Rs. ${bike.pricePerMinute}/min'),
              bike.isAvailable
                  ? const Text(
                      '✅ Available',
                      style: TextStyle(color: Colors.green),
                    )
                  : Text(
                      '❌ Not Available\nAvailable in ${bike.availableInMinutes ?? '?'} mins',
                      style: const TextStyle(color: Colors.red),
                    ),
              if (isUnlocked)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '🔓 Bike is unlocked',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
            ],
          ),
          actions: [
            if (!isUnlocked && bike.isAvailable)
              ElevatedButton(
                onPressed: () async {
                  final url = Uri.parse(
                    'http://172.16.31.132:8000/api/v1/bikes/code/${bike.code}/otp',
                  );
                  try {
                    final response = await http.get(url);
                    if (response.statusCode == 200) {
                      final data = jsonDecode(response.body);
                      final otp = data['otp'].toString();
                      Navigator.pop(context);
                      final unlocked = await _showOtpDialog(context, bike, otp);
                      if (unlocked == true) {
                        setState(() => isUnlocked = true);
                        _showBikeDetails(bike);
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to fetch OTP')),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Unlock'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showOtpDialog(
    BuildContext context,
    Bike bike,
    String serverOtp,
  ) {
    final TextEditingController _otpController = TextEditingController();

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter OTP'),
        content: TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: const InputDecoration(labelText: 'OTP'),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (_otpController.text.trim() == serverOtp) {
                Navigator.of(context).pop(true);
                _showConfirmRideDialog(context, bike);
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('❌ Invalid OTP')));
              }
            },
            child: const Text('Submit'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showConfirmRideDialog(BuildContext context, Bike bike) {
    final TextEditingController _startController = TextEditingController();
    final TextEditingController _endController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Ride'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Bike: ${bike.name}'),
            TextField(
              controller: _startController,
              decoration: const InputDecoration(labelText: 'Start'),
            ),
            TextField(
              controller: _endController,
              decoration: const InputDecoration(labelText: 'End'),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final start = _startController.text.trim().toLowerCase();
              final end = _endController.text.trim().toLowerCase();

              if (start.isEmpty || end.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill both fields')),
                );
                return;
              }

              if (!stationCoordinates.containsKey(start) ||
                  !stationCoordinates.containsKey(end)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid station names')),
                );
                return;
              }

              final startCoord = stationCoordinates[start]!;
              final endCoord = stationCoordinates[end]!;

              try {
                // Call fetchRoute to get path along roads
                final routePoints = await fetchRoute(startCoord, endCoord);

                final distance = calculateDistanceInKm(startCoord, endCoord);
                final formattedDistance = distance.toStringAsFixed(2);

                setState(() {
                  pathPoints = routePoints; // Update with actual route points
                });

                Navigator.of(context).pop();

                // Show confirmation dialog with route info
                Future.delayed(Duration.zero, () {
                  _showEsewaPaymentDialog(context, bike, start, end, distance);
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Ride Confirmed'),
                      content: Text(
                        'From "$start" to "$end"\nDistance: $formattedDistance km\nBike: ${bike.name}\nRate: Rs. ${bike.pricePerMinute}/min',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                });
              } catch (e) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error fetching route: $e')),
                );
              }
            },
            child: const Text('Confirm'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showEsewaPaymentDialog(
    BuildContext context,
    Bike bike,
    String start,
    String end,
    double distance,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment with eSewa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('From "$start" to "$end"'),
            Text('Distance: ${distance.toStringAsFixed(2)} km'),
            Text('Bike: ${bike.name}'),
            Text('Rate: Rs. ${bike.pricePerMinute}/min'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: Implement eSewa payment integration here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('eSewa payment process started (simulated).'),
                  ),
                );
              },
              child: const Text('Pay Now'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
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
                    // Station markers
                    ..._stations.map(
                      (station) => Marker(
                        point: LatLng(station.lat, station.lng),
                        width: 80,
                        height: 80,
                        child: IconButton(
                          icon: const Icon(
                            Icons.location_on,
                            color: Colors.black,
                            size: 35,
                          ),
                          onPressed: () => _showStationDetails(station),
                        ),
                      ),
                    ),
                    // Current location marker (user)
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
