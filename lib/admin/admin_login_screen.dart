import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _error;

  final storage = FlutterSecureStorage();

  Future<void> _login() async {
    setState(() {
      _error = null; // Clear previous errors on new login attempt
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    // Basic validation before making the API call
    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Please enter both username and password.';
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://backend-bicycle-1.onrender.com/api/v1/admin/login'),
        body: jsonEncode({'username': username, 'password': password}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        await storage.write(key: 'admin_token', value: token); // Store token
        // Navigate to the admin panel after successful login
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        // Handle different error statuses if needed
        String errorMessage = 'Invalid admin credentials';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          // If response body is not JSON or message field is missing
          print('Failed to parse error response: $e');
        }
        setState(() {
          _error = errorMessage;
        });
      }
    } catch (e) {
      // Catch network errors or other exceptions
      setState(() {
        _error = 'Failed to connect to the server. Please try again.';
      });
      print('Login error: $e'); // Log the error for debugging
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Login')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              // THIS IS THE FIX: Call the _login() method
              onPressed: _login,
              child: const Text("Login as Admin"),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
