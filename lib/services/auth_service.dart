import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:zupito/api/api_config.dart'; // Make sure backendUrl is defined here
import 'package:zupito/services/secure_storage_services.dart';

class AuthService {
  // ✅ Correct baseUrl using the real device-compatible local IP address
  static const String baseUrl = '$backendUrl/api/v1/auth';

  final SecureStorageService _secureStorage = SecureStorageService();

  // 🔐 Login
  // 🔐 Login
  Future<Map<String, dynamic>?> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("✅ Login successful. Response data: $data");

        final token = data['token'];
        final user = data['user'];

        if (token != null && user != null) {
          // ✅ Save token
          await _secureStorage.saveToken(token);

          // ✅ Save user ID (or username as fallback)
          await _secureStorage.saveUserId(user['_id'] ?? username);

          // ✅ Save full user JSON
          await _secureStorage.saveUser(jsonEncode(user));

          // ✅ Return both token and user
          return {'token': token, 'user': user};
        } else {
          print("❌ Token or user is missing in response.");
          return null;
        }
      } else {
        print("❌ Login failed with status ${response.statusCode}");
        print("❌ Response body: ${response.body}");
        return null;
      }
    } catch (e) {
      print('❌ Error during login: $e');
      return null;
    }
  }

  // 📝 Signup (updated: no auto-login)
  Future<bool> signup(
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
        print('✅ Signup successful');
        return true;
      } else {
        print('❌ Signup failed with status ${response.statusCode}');
        print('❌ Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error during signup: $e');
      return false;
    }
  }
}
