import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/ride.dart';

class RideService {
  // Make currentRide nullable and private
  static Ride? _currentRide;

  // Getter for currentRide
  static Ride? get currentRide => _currentRide;

  // Method to set a new ride (e.g., when a user starts a ride)
  // This needs to create a full Ride object with required fields.
  // You'll need to pass in the actual RideUser and RideBike objects here
  // when a ride is initiated in your user-facing app.
  // For simplicity, I'm using placeholder/dummy data for user/bike for now.
  static void startRide({
    required String rideId, // Assuming you get an ID from backend on ride start
    required RideUser user,
    required RideBike bike,
    RideStation? startStation,
  }) {
    _currentRide = Ride(
      id: rideId,
      user: user,
      bike: bike,
      startStation: startStation,
      fare: 0.0, // Initial fare is 0
      startTime: DateTime.now(),
      status: 'ongoing', // Set initial status
      endTime: null, // No end time yet
    );
  }

  // This method is for calculating fare *before* sending to backend.
  // It updates the existing _currentRide object.
  static Ride stopRideAndCalculateFare(double fare) {
    if (_currentRide == null) throw Exception("No ride in progress");

    // Update the existing ride object with new fare and end time
    _currentRide = Ride(
      id: _currentRide!.id,
      user: _currentRide!.user,
      bike: _currentRide!.bike,
      startStation: _currentRide!.startStation,
      fare: fare,
      startTime: _currentRide!.startTime,
      endTime: DateTime.now(),
      status: 'completed', // Status becomes completed after calculation
      distance: _currentRide!.distance, // Preserve existing distance if any
      penaltyAmount: _currentRide!.penaltyAmount, // Preserve existing penalty
    );

    return _currentRide!;
  }

  static Future<List<LatLng>> fetchRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final coords = data['routes'][0]['geometry']['coordinates'] as List;
      return coords.map((p) => LatLng(p[1], p[0])).toList();
    } else {
      throw Exception('Failed to fetch route');
    }
  }

  static void drawRoute(
    BuildContext context,
    LatLng start,
    LatLng end,
    Function(List<LatLng>) onRouteFetched,
  ) async {
    try {
      final route = await fetchRoute(start, end);
      onRouteFetched(route);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error drawing route: $e')));
    }
  }

  // This `endRide` method seems to be for the user-facing app
  // and interacts with a different backend endpoint than the admin ones.
  // Ensure 'https://your-backend-url.com/api/rides/end' is the correct endpoint.
  static Future<Map<String, dynamic>> endRide({
    required String rideId,
    required double latitude,
    required double longitude,
    // You might also need to pass fare, duration, etc., here if the backend expects it.
    // The backend's endRide function should update the ride status to 'completed'
    // and calculate fare/penalty.
  }) async {
    final url = Uri.parse(
      'https://your-backend-url.com/api/rides/end',
    ); // 🔁 Replace with your real backend URL

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'rideId': rideId,
        'userLocation': {'latitude': latitude, 'longitude': longitude},
        // Potentially add 'fare', 'duration', 'distance' here if the backend expects them
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(
        'Failed to end ride: ${errorBody['error'] ?? 'Unknown error'} (Status: ${response.statusCode})',
      );
    }
  }
}
