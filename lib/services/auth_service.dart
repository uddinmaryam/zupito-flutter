import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:zupito/api/api_config.dart'; // backendUrl imported here
import 'package:zupito/services/secure_storage_services.dart';

class AuthService {
  static const String baseUrl = '$backendUrl/api/auth';

  final SecureStorageService _secureStorage = SecureStorageService();

  Future<String?> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['token'];
      } else {
        print('Login failed: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error during login: $e');
      return null;
    }
  }

  Future<String?> signup(
    String username,
    String email,
    String password,
    String phone,
  ) async {
    final url = Uri.parse('$baseUrl/register');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'phone': phone,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Signup success, now try login to get token
        print('Signup successful, now logging in...');
        return await login(username, password);
      } else {
        print('Signup failed: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error during signup: $e');
      return null;
    }
  }

  Future<http.Response?> getProtectedData() async {
    final token = await _secureStorage.getToken();

    if (token == null) {
      print('No token found, user might not be logged in');
      return null;
    }

    final url = Uri.parse('$backendUrl/api/protected-route');

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      return response;
    } catch (e) {
      print('Error fetching protected data: $e');
      return null;
    }
  }
}
