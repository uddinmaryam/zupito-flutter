import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AdminApiService {
  static const String baseUrl =
      'https://backend-bicycle-1.onrender.com/api/v1/admin';
  static const FlutterSecureStorage _storage =
      FlutterSecureStorage(); // Make storage a static final field

  // Helper method to get the authorization token
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _storage.read(key: 'admin_token');
    if (token == null) {
      // Consider a more specific exception or callback here
      throw Exception('No admin token found. Please log in again.');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // --- Generic HTTP Methods ---

  static Future<dynamic> _get(String path) async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: headers,
    );
    return _handleResponse(response);
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: jsonEncode(body), // Use jsonEncode here
    );
    return _handleResponse(response);
  }

  static Future<dynamic> _delete(String path) async {
    final headers = await _getAuthHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: headers,
    );
    return _handleResponse(response);
  }

  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Handle empty response body for 204 No Content
      if (response.body.isNotEmpty) {
        return jsonDecode(response.body);
      }
      return null; // For successful deletions or empty responses
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      // Specific handling for authentication/authorization errors
      // In a real app, you'd likely want to clear the token and navigate to login
      throw Exception(
        'Authentication Error: ${jsonDecode(response.body)['message'] ?? 'Invalid or expired token.'}',
      );
    } else {
      // General error handling
      final errorBody = jsonDecode(response.body);
      throw Exception(
        'API Error (${response.statusCode}): ${errorBody['message'] ?? 'An unknown error occurred.'}',
      );
    }
  }

  // --- Specific API Calls using generic methods ---

  static Future<Map<String, dynamic>> fetchSummary() async {
    return await _get('/summary');
  }

  static Future<List<dynamic>> fetchUsers() async {
    return await _get('/users');
  }

  static Future<List<dynamic>> fetchBikes() async {
    return await _get('/bikes');
  }

  static Future<Map<String, dynamic>> addBike(
    Map<String, dynamic> bikeData,
  ) async {
    return await _post('/bikes', bikeData);
  }

  static Future<void> deleteBike(String bikeId) async {
    await _delete('/bikes/$bikeId');
  }

  static Future<List<dynamic>> fetchStations() async {
    return await _get('/stations');
  }

  static Future<Map<String, dynamic>> addStation(
    Map<String, dynamic> stationData,
  ) async {
    return await _post('/stations', stationData);
  }

  static Future<void> deleteStation(String stationId) async {
    await _delete('/stations/$stationId');
  }

  static Future<List<dynamic>> fetchRides() async {
    return await _get('/rides');
  }

  // Admin Login (special case, no auth token needed for this request)
  static Future<String> adminLogin(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'];
      if (token != null) {
        await _storage.write(key: 'admin_token', value: token);
        return token;
      } else {
        throw Exception('Login successful but no token received.');
      }
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Login failed');
    }
  }

  static Future<void> logout() async {
    await _storage.delete(key: 'admin_token');
  }

// Fetch pending users
  static Future<List<dynamic>> fetchPendingUsers() async {
    return await _get('/pending-users');
  }

// Approve user
  static Future<void> approveUser(String userId) async {
    // No body needed, so pass empty map for POST
    await _post('/approve-user/$userId', {});
  }

// Reject user
  static Future<void> rejectUser(String userId) async {
    await _delete('/reject-user/$userId');
  }
}
