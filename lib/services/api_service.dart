// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/station.dart'; // Import your Station model

class ApiService {
  static const String _baseUrl =
      'https://backend-bicycle-1.onrender.com/api/v1'; // ✅ IMPORTANT: Your Node.js backend URL

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

  // New method to fetch all stations
  Future<List<Station>> getStations() async {
    final url = Uri.parse('$_baseUrl/stations');

    try {
      final response = await http.get(url, headers: _getHeaders());

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonMap = json.decode(response.body);
        final List<dynamic> jsonList = jsonMap['stations']; // ✅ this is key

        return jsonList.map((json) => Station.fromJson(json)).toList();
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(
          'Failed to load stations: ${errorBody['message'] ?? 'Unknown error'} (Status: ${response.statusCode})',
        );
      }
    } catch (e) {
      throw Exception('Error calling getStations API: $e');
    }
  }

  Future<Map<String, dynamic>> startRide({
    required String userId,
    required String bikeId,
    required int selectedDuration,
    required String startStationId, // Explicitly passing start station ID
    required String
    destinationStationId, // Explicitly passing destination station ID
    required double estimatedCost,
    // ADDED THESE TWO PARAMETERS:
    required double startLat, // <--- Corrected: Now a required parameter
    required double startLng, // <--- Corrected: Now a required parameter
  }) async {
    final url = Uri.parse('$_baseUrl/rides/start');
    try {
      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: json.encode({
          'userId': userId,
          'bikeId': bikeId,
          'selectedDuration': selectedDuration,
          'startStationId': startStationId, // Send start station ID
          'destinationStationId': destinationStationId, // Send destination ID
          'estimatedCost': estimatedCost,
          'startLocation': {
            // Send location explicitly
            'latitude': startLat,
            'longitude': startLng,
          },
        }),
      );
      print('Start Ride API Response Status: ${response.statusCode}');
      print('Start Ride API Response Body: ${response.body}');

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(
          'Failed to start ride: ${errorBody['error'] ?? errorBody['message'] ?? 'Unknown error'} (Status: ${response.statusCode})', // Improved error message parsing
        );
      }
    } catch (e) {
      throw Exception('Error calling startRide API: $e');
    }
  }

  Future<Map<String, dynamic>> endRide({
    required String rideId,
    required LatLng userLocation,
  }) async {
    final url = Uri.parse('$_baseUrl/rides/end'); // ✅ Correct base URL used

    final response = await http.post(
      url,
      headers: _getHeaders(), // ✅ Use proper headers (with token if available)
      body: jsonEncode({
        'rideId': rideId,
        'userLocation': {
          'latitude': userLocation.latitude,
          'longitude': userLocation.longitude,
        },
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(
        errorBody['error'] ?? 'Unknown error (Status: ${response.statusCode})',
      );
    }
  }

  Future getActiveRide() async {
    final url = Uri.parse('$_baseUrl/rides/active');
    try {
      final response = await http.get(url, headers: _getHeaders());
      print('Get Active Ride API Response Status: ${response.statusCode}');
      print('Get Active Ride API Response Body: ${response.body}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = json.decode(response.body);
        if (responseBody['activeRide'] == true) {
          return responseBody['rideDetails'];
        }
        return null;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(
          'Failed to get active ride: ${errorBody['message'] ?? 'Unknown error'} (Status: ${response.statusCode})',
        );
      }
    } catch (e) {
      print('Error checking for active ride: $e');
      return null;
    }
  }

Future<Map<String, dynamic>> fetchRideSummary(String userId) async {
  final response = await http.get(
    Uri.parse('$_baseUrl/rides/user/$userId/summary'),
    headers: _getHeaders(),
  );
  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to load ride summary');
  }
}

Future<List<Map<String, dynamic>>> fetchRideHistory(String userId) async {
  final response = await http.get(
    Uri.parse('$_baseUrl/rides/user/$userId'),
    headers: _getHeaders(),
  );
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data);
  } else {
    throw Exception('Failed to load ride history');
  }
}
}