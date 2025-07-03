// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart'; // Make sure this is imported

class ApiService {
  static const String _baseUrl =
      'https://backend-bicycle-1.onrender.com/api'; // ✅ IMPORTANT: Your Node.js backend URL

  String? _authToken; // Assuming you handle authentication elsewhere

  void setAuthToken(String token) {
    _authToken = token;
  }

  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_authToken != null) 'Authorization': 'Bearer $_authToken',
    };
  }

  // Existing methods (e.g., unlockBike) can go here

  // ✅ NEW: startRide method
  Future<Map<String, dynamic>> startRide({
    required String userId, // Added userId as a requirement
    required String bikeId,
    required int selectedDuration,
  }) async {
    final url = Uri.parse('$_baseUrl/ride/start'); // Your backend endpoint
    try {
      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: json.encode({
          'userId': userId,
          'bikeId': bikeId,
          'selectedDuration': selectedDuration,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(
          response.body,
        ); // Expect success, rideId, bikeCode, rideEndTime, bikeLocation
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(
          'Failed to start ride: ${errorBody['message'] ?? 'Unknown error'} (Status: ${response.statusCode})',
        );
      }
    } catch (e) {
      throw Exception('Error calling startRide API: $e');
    }
  }

  // ✅ NEW: endRide method
  Future<Map<String, dynamic>> endRide({
    required String rideId,
    required LatLng userLocation,
  }) async {
    final url = Uri.parse('$_baseUrl/ride/end'); // Your backend endpoint
    try {
      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: json.encode({
          'rideId': rideId,
          'userLocation': {
            'latitude': userLocation.latitude,
            'longitude': userLocation.longitude,
          },
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body); // Expect success, message
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(
          'Failed to end ride: ${errorBody['message'] ?? 'Unknown error'} (Status: ${response.statusCode})',
        );
      }
    } catch (e) {
      throw Exception('Error calling endRide API: $e');
    }
  }
}
