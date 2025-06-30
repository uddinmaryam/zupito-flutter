import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/ride.dart';

class RideService {
  static Ride? currentRide;

  static void startRide(String bikeId) {
    currentRide = Ride(
      bikeId: bikeId,
      fare: 0.0,
      startTime: DateTime.now(),
      endTime: DateTime.now(),
    );
  }

  static Ride stopRideAndCalculateFare(double fare) {
    if (currentRide == null) throw Exception("No ride in progress");

    currentRide = Ride(
      bikeId: currentRide!.bikeId,
      fare: fare,
      startTime: currentRide!.startTime,
      endTime: DateTime.now(),
    );

    return currentRide!;
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
}
