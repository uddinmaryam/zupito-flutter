import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AdminApiService {
  static const String baseUrl =
      'https://backend-bicycle-1.onrender.com/api/v1/admin';

  // No longer need a static headers map with hardcoded token
  // static const Map<String, String> headers = {
  //   'Authorization': 'Bearer admin123',
  //   'Content-Type': 'application/json',
  // };

  // Helper method to get the authorization token
  static Future<Map<String, String>> _getAuthHeaders() async {
    final storage = FlutterSecureStorage();
    final token = await storage.read(key: 'admin_token');
    if (token == null) {
      throw Exception('No admin token found. Please log in again.');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  static Future<Map<String, dynamic>> fetchSummary() async {
    final headers = await _getAuthHeaders(); // Use the helper
    final response = await http.get(
      Uri.parse('$baseUrl/summary'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load summary: ${response.body}');
    }
  }

  static Future<List<dynamic>> fetchUsers() async {
    final headers = await _getAuthHeaders(); // Use the helper
    final response = await http.get(
      Uri.parse('$baseUrl/users'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      // It's good practice to include the response body for debugging
      throw Exception('Failed to load users: ${response.body}');
    }
  }

  static Future<List<dynamic>> fetchBikes() async {
    final headers = await _getAuthHeaders(); // Use the helper
    final response = await http.get(
      Uri.parse('$baseUrl/bikes'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load bikes: ${response.body}');
    }
  }

  static Future<List<dynamic>> fetchStations() async {
    final headers = await _getAuthHeaders(); // Use the helper
    final response = await http.get(
      Uri.parse('$baseUrl/stations'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load stations: ${response.body}');
    }
  }

  static Future<List<dynamic>> fetchRides() async {
    final headers = await _getAuthHeaders(); // Use the helper
    final response = await http.get(
      Uri.parse('$baseUrl/rides'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load rides: ${response.body}');
    }
  }
}
