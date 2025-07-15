// lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:zupito/models/bike.dart';
import 'package:zupito/models/station.dart';
import 'package:zupito/models/user.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static const String _baseUrl =
      'https://backend-bicycle-1.onrender.com/api/v1';

  String? _authToken;

  void setAuthToken(String token) {
    _authToken = token;
  }

  Map<String, String> getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_authToken != null) 'Authorization': 'Bearer $_authToken',
    };
  }

  Future<List<Station>> getStations() async {
    final url = Uri.parse('$_baseUrl/stations');
    try {
      final response = await http.get(url, headers: getHeaders());

      debugPrint(
        '--- Raw JSON Response for getStations (${response.statusCode}) ---',
      );
      debugPrint(response.body);

      if (response.statusCode == 200) {
        final dynamic decodedBody = json.decode(response.body);

        // Case 1: Top-level list
        if (decodedBody is List) {
          return decodedBody
              .where((jsonItem) => jsonItem is Map<String, dynamic>)
              .map(
                (jsonItem) =>
                    Station.fromJson(jsonItem as Map<String, dynamic>),
              )
              .toList();
        }

        // Case 2: Object with 'stations' or 'data' key
        if (decodedBody is Map<String, dynamic>) {
          if (decodedBody.containsKey('stations')) {
            final stationsList = decodedBody['stations'];
            if (stationsList is List) {
              return stationsList
                  .where((jsonItem) => jsonItem is Map<String, dynamic>)
                  .map(
                    (jsonItem) =>
                        Station.fromJson(jsonItem as Map<String, dynamic>),
                  )
                  .toList();
            }
          }
          if (decodedBody.containsKey('data')) {
            final dataList = decodedBody['data'];
            if (dataList is List) {
              return dataList
                  .where((jsonItem) => jsonItem is Map<String, dynamic>)
                  .map(
                    (jsonItem) =>
                        Station.fromJson(jsonItem as Map<String, dynamic>),
                  )
                  .toList();
            }
          }
        }

        throw Exception('Unexpected response format for stations API.');
      } else {
        String errorMessage = 'Unknown error';
        try {
          final errorBody = json.decode(response.body);
          errorMessage = errorBody['message'] ??
              errorBody['error'] ??
              'Server responded with status ${response.statusCode}';
        } catch (e) {
          errorMessage =
              'Failed to parse error response: ${response.body} (Status: ${response.statusCode})';
        }
        throw Exception('Failed to load stations: $errorMessage');
      }
    } catch (e) {
      debugPrint('Error calling getStations API: $e');
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
        headers: getHeaders(),
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
      debugPrint('Start Ride API Response Status: ${response.statusCode}');
      debugPrint('Start Ride API Response Body: ${response.body}');

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
    required double endLat,
    required double endLng,
  }) async {
    final url = Uri.parse('$_baseUrl/rides/end');

    final response = await http.post(
      url,
      headers: getHeaders(),
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
      final response = await http.get(url, headers: getHeaders());
      debugPrint('Get Active Ride API Response Status: ${response.statusCode}');
      debugPrint('Get Active Ride API Response Body: ${response.body}');
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
      debugPrint('Error checking for active ride: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> fetchRideSummary(String userId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/rides/user/$userId/summary'),
      headers: getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
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
    debugPrint('Attempting to fetch ride history from URL: $url');
    try {
      final response = await http.get(url, headers: getHeaders());

      debugPrint('Ride History API Response Status: ${response.statusCode}');
      debugPrint('Ride History API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else {
          debugPrint(
            'Ride History API: Expected a List, but received: ${data.runtimeType}',
          );
          throw Exception(
            'Failed to load ride history: Unexpected data format',
          );
        }
      } else {
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
      debugPrint('Error in fetchRideHistory API call: $e');
      throw Exception('Error calling fetchRideHistory API: $e');
    }
  }

  Future<List<Bike>> getBikes() async {
    final url = Uri.parse('$_baseUrl/bikes');

    try {
      final response = await http.get(url, headers: getHeaders());

      debugPrint(
        '--- Raw JSON Response for getBikes (${response.statusCode}) ---',
      );
      debugPrint(response.body);
      debugPrint('----------------------------------------------------');

      if (response.statusCode == 200) {
        final dynamic decodedBody = json.decode(response.body);

        if (decodedBody is List) {
          debugPrint(
            'DEBUG: getBikes received top-level List. Mapping directly.',
          );
          return decodedBody.map((jsonItem) {
            debugPrint(
              'DEBUG: Processing jsonItem type: ${jsonItem.runtimeType}',
            );
            if (jsonItem is Map<String, dynamic>) {
              return Bike.fromJson(jsonItem);
            } else {
              throw Exception(
                'Expected Map<String, dynamic> but got ${jsonItem.runtimeType} in bikes list.',
              );
            }
          }).toList();
        } else if (decodedBody is Map<String, dynamic> &&
            decodedBody.containsKey('bikes')) {
          final List<dynamic> jsonList = decodedBody['bikes'];
          debugPrint(
            'DEBUG: getBikes received Map with "bikes" key. Mapping "bikes" list.',
          );
          return jsonList.map((jsonItem) {
            debugPrint(
              'DEBUG: Processing jsonItem type: ${jsonItem.runtimeType}',
            );
            if (jsonItem is Map<String, dynamic>) {
              return Bike.fromJson(jsonItem);
            } else {
              throw Exception(
                'Expected Map<String, dynamic> but got ${jsonItem.runtimeType} in "bikes" list.',
              );
            }
          }).toList();
        } else {
          throw Exception(
            'Unexpected response format for bikes API. Expected a List or a Map with a "bikes" key.',
          );
        }
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(
          'Failed to load bikes: ${errorBody['message'] ?? 'Unknown error'} (Status: ${response.statusCode})',
        );
      }
    } catch (e) {
      debugPrint('Error calling getBikes API: $e');
      throw Exception('Error calling getBikes API: $e');
    }
  }
  // import your model

  Future<List<User>> fetchUsers() async {
    final response =
        await http.get(Uri.parse("https://your-backend-url.com/api/users"));

    if (response.statusCode == 200) {
      List<dynamic> usersJson = json.decode(response.body);
      return usersJson.map((userJson) => User.fromJson(userJson)).toList();
    } else {
      throw Exception("Failed to load users");
    }
  }
}
