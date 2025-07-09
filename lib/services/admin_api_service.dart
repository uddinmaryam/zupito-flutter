import 'dart:convert';
import 'package:http/http.dart' as http;

class AdminApiService {
  static const String baseUrl =
      'https://backend-bicycle-1.onrender.com/api/v1/admin';
  static const Map<String, String> headers = {
    'Authorization': 'Bearer admin123',
    'Content-Type': 'application/json',
  };

  static Future<Map<String, dynamic>> fetchSummary() async {
    final response = await http.get(
      Uri.parse('$baseUrl/summary'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load summary');
    }
  }

  static Future<List<dynamic>> fetchUsers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load users');
    }
  }

  static Future<List<dynamic>> fetchBikes() async {
    final response = await http.get(
      Uri.parse('$baseUrl/bikes'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load bikes');
    }
  }

  static Future<List<dynamic>> fetchStations() async {
    final response = await http.get(
      Uri.parse('$baseUrl/stations'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load stations');
    }
  }

  static Future<List<dynamic>> fetchRides() async {
    final response = await http.get(
      Uri.parse('$baseUrl/rides'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load rides');
    }
  }
}
