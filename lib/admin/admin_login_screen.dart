import 'package:flutter/material.dart';
import 'package:zupito/services/auth_service.dart'; // Make sure this is the correct path
import 'package:zupito/services/secure_storage_services.dart'; // Make sure this is the correct path
import 'package:zupito/admin/admin_home_screen.dart'; // Ensure this is imported for pushReplacement

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService =
      AuthService(); // Use AuthService for admin login
  final SecureStorageService _secureStorage = SecureStorageService();

  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAdminLogin() async {
    setState(() {
      _isLoading = true;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter admin username and password'),
        ),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Assuming your AuthService.login can handle admin credentials
      // and returns a token and user object, similar to regular user login.
      // If your backend has a separate admin login endpoint, you'll need
      // a specific method in AuthService for it. For now, we'll assume `login` works.
      final result = await _authService.login(username, password);

      if (result != null && result['token'] != null) {
        // Assuming admin token is stored separately or identified
        await _secureStorage.writeAdminToken(result['token']);

        if (!mounted) return;
        // FIX: Navigate to the correct admin home route '/admin'
        // This is the line that was causing the error in your screenshot.
        // It must match a route defined in your MaterialApp in main.dart.
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin login failed. Invalid credentials.'),
          ),
        );
      }
    } catch (e) {
      print("❌ Admin login exception: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'An error occurred during admin login: ${e.toString()}',
          ),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0FE), // Consistent background
      appBar: AppBar(
        title: const Text('Admin Login'),
        backgroundColor: Colors.blueAccent, // Admin specific app bar color
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.admin_panel_settings,
                size: 80,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Admin Username',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Admin Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleAdminLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Login as Admin',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
