// lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/station.dart';
// If you have these models and they are used, keep these imports.
// If not, you might not need them, but it's generally safer to keep if they exist.
// import '../models/bike.dart';
// import '../models/user.dart';

class ApiService {
  static const String _baseUrl =
      'https://backend-bicycle-1.onrender.com/api/v1';

  String? _authToken;

  void setAuthToken(String token) {
    _authToken = token;
  }

  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_authToken != null) 'Authorization': 'Bearer $_authToken',
    };
  }

  Future<List<Station>> getStations() async {
    final url = Uri.parse('$_baseUrl/stations');

    try {
      final response = await http.get(url, headers: _getHeaders());

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonMap = json.decode(response.body);
        final List<dynamic> jsonList = jsonMap['stations'];

        print('--- Raw JSON Response for all Stations from getStations ---');
        print(jsonEncode(jsonMap));
        print('----------------------------------------------------');

        return jsonList.map((jsonItem) {
          if (jsonItem['name'] == 'Dhobighat') {
            print('--- Raw JSON for Dhobighat Station (before parsing) ---');
            print(jsonEncode(jsonItem));
            print('----------------------------------------------------');
            print('Dhobighat bikes array in raw JSON: ${jsonItem['bikes']}');
          }
          return Station.fromJson(jsonItem as Map<String, dynamic>);
        }).toList();
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
    required String startStationId,
    required String destinationStationId,
    required double estimatedCost,
    required double startLat,
    required double startLng,
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
          'startStationId': startStationId,
          'destinationStationId': destinationStationId,
          'estimatedCost': estimatedCost,
          'startLocation': {'latitude': startLat, 'longitude': startLng},
        }),
      );
      print('Start Ride API Response Status: ${response.statusCode}');
      print('Start Ride API Response Body: ${response.body}');

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(
          'Failed to start ride: ${errorBody['error'] ?? errorBody['message'] ?? 'Unknown error'} (Status: ${response.statusCode})',
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
    final url = Uri.parse('$_baseUrl/rides/end');

    final response = await http.post(
      url,
      headers: _getHeaders(),
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
      // This is the correct URL for fetching the ride summary (totalRides, totalDistance, totalPenalty)
      Uri.parse('$_baseUrl/rides/user/$userId/summary'),
      headers: _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      // It's good practice to include more details in the exception for debugging
      String errorMessage = 'Unknown error';
      try {
        final errorBody = jsonDecode(response.body);
        errorMessage =
            errorBody['message'] ?? errorBody['error'] ?? errorMessage;
      } catch (e) {
        errorMessage = 'Failed to parse error body: $e';
      }
      throw Exception(
        'Failed to load ride summary: $errorMessage (Status: ${response.statusCode})',
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchRideHistory(String userId) async {
    final url = Uri.parse('$_baseUrl/rides/user/$userId/history');
    print('Attempting to fetch ride history from URL: $url'); // New debug print
    try {
      final response = await http.get(url, headers: _getHeaders());

      print(
        'Ride History API Response Status: ${response.statusCode}',
      ); // New debug print
      print(
        'Ride History API Response Body: ${response.body}',
      ); // New debug print

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Ensure data is indeed a List, as per Postman screenshot
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else {
          // If the response is not a List, it's an unexpected format
          print(
            'Ride History API: Expected a List, but received: ${data.runtimeType}',
          );
          throw Exception(
            'Failed to load ride history: Unexpected data format',
          );
        }
      } else {
        // Parse the error body if available
        String errorMessage = 'Unknown error';
        try {
          final errorBody = jsonDecode(response.body);
          errorMessage =
              errorBody['message'] ?? errorBody['error'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'Failed to parse error body: $e';
        }
        throw Exception(
          'Failed to load ride history: $errorMessage (Status: ${response.statusCode})',
        );
      }
    } catch (e) {
      print(
        'Error in fetchRideHistory API call: $e',
      ); // Catch network or parsing errors
      throw Exception(
        'Error calling fetchRideHistory API: $e',
      ); // Re-throw with more context
    }
  }

  Future<Map<String, dynamic>> login({
    required String phone,
    required String otp,
  }) async {
    final url = Uri.parse('$_baseUrl/auth/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'otp': otp}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Login failed: ${jsonDecode(response.body)['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      throw Exception('Error during login: $e');
    }
  }
}
