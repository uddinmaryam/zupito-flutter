import 'dart:convert';
import 'dart:io'; // Import for File
import 'package:http/http.dart' as http;
import 'package:zupito/api/api_config.dart'; // Ensure this path is correct
import 'package:zupito/services/secure_storage_services.dart'; // Ensure this path is correct

class AuthService {
  // Use the backendUrl from your api_config.dart
  static const String baseUrl = '$backendUrl/api/v1/auth';
  static const String adminBaseUrl = '$backendUrl/api/v1/admin';

  final SecureStorageService _secureStorage = SecureStorageService();

  // 🔐 General User Login with Username and Password
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
        print("✅ General user login successful. Response data: $data");

        final token = data['token'];
        final user = data['user'];

        if (token != null && user != null) {
          await _secureStorage.writeUserAuthToken(token);
          await _secureStorage.writeUserProfile(jsonEncode(user));
          return {'token': token, 'user': user};
        } else {
          print("❌ Token or user is missing in general user login response.");
          return null;
        }
      } else {
        print("❌ General user login failed with status ${response.statusCode}");
        print("❌ Response body: ${response.body}");
        return null;
      }
    } catch (e) {
      print('❌ Error during general user login: $e');
      return null;
    }
  }

  // 🔐 Admin Login with Username and Password
  Future<Map<String, dynamic>?> adminLogin(
    String username,
    String password,
  ) async {
    final url = Uri.parse('$adminBaseUrl/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("✅ Admin login successful. Response data: $data");

        final token = data['token'];
        final user = data['user'];

        if (token != null) {
          await _secureStorage.writeAdminToken(token);
          // Optionally store admin user profile if needed
          if (user != null) {
            // await _secureStorage.writeAdminProfile(jsonEncode(user));
          }
          return {'token': token, 'user': user};
        } else {
          print("❌ Token is missing in admin login response.");
          return null;
        }
      } else {
        print("❌ Admin login failed with status ${response.statusCode}");
        print("❌ Response body: ${response.body}");
        return null;
      }
    } catch (e) {
      print('❌ Error during admin login: $e');
      return null;
    }
  }

  // 📝 Signup (UPDATED to include citizenshipNumber and citizenshipImage)
  Future<bool> signup({
    required String username,
    required String email,
    required String password,
    required String phone,
    required String citizenshipNumber, // New required parameter
    required File citizenshipImage, // New required parameter for image file
  }) async {
    final url = Uri.parse('$baseUrl/register');

    try {
      // Use MultipartRequest for file uploads
      final request = http.MultipartRequest('POST', url);

      // Add text fields
      request.fields['username'] = username;
      request.fields['email'] = email;
      request.fields['password'] = password;
      request.fields['phone'] = phone;
      request.fields['citizenshipNumber'] =
          citizenshipNumber; // Add citizenship number
      request.fields['role'] =
          'user'; // Assuming default role is 'user' as per your schema

      // Add the file
      request.files.add(
        await http.MultipartFile.fromPath(
          'citizenshipImage', // This 'citizenshipImage' MUST match the field name in your Multer setup (upload.single('citizenshipImage'))
          citizenshipImage.path,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Signup successful');
        print('Response body: ${response.body}');
        return true;
      } else {
        print('❌ Signup failed with status ${response.statusCode}');
        print('❌ Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error during signup API call: $e');
      return false;
    }
  }
}
