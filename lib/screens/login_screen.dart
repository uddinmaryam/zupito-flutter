import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:zupito/screens/map/map_screen.dart';
import '../services/auth_service.dart';
import '../services/secure_storage_services.dart';
import 'signup_screen.dart';
import '../services/otp_socket_service.dart';
import 'package:zupito/api/api_config.dart'; // Import api_config to check backendUrl

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService authService = AuthService();
  final SecureStorageService _secureStorage = SecureStorageService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleUsernamePasswordLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    print(
      "DEBUG: Login button pressed. Username: $username, Password: $password",
    );

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter username and password')),
      );
      print("DEBUG: Username or password is empty.");
      return;
    }

    // DEBUG: Print the backend URL being used
    print(
      "DEBUG: Attempting login to backend URL: ${AuthService.baseUrl}/login",
    );
    print("DEBUG: Backend URL from api_config: $backendUrl");

    try {
      final result = await authService.login(username, password);
      print("DEBUG: Auth service login call completed. Result: $result");

      if (result != null && result['token'] != null && result['user'] != null) {
        print("DEBUG: Login successful. Saving token and user profile.");
        await _secureStorage.writeUserAuthToken(result['token']);
        await _secureStorage.writeUserProfile(jsonEncode(result['user']));

        final userId = result['user']['_id'] ?? result['user']['id'];
        if (userId != null) {
          print('DEBUG: Connecting socket for userId: $userId');
          OtpSocketService().connect(userId.toString(), context: context);
        } else {
          print("DEBUG: User ID is null after login.");
        }

        if (!mounted) {
          print("DEBUG: Widget not mounted, cannot navigate.");
          return;
        }
        print("DEBUG: Navigating to MapScreen.");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
      } else {
        print("DEBUG: Login failed. Result was null or missing token/user.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login failed. Check credentials.')),
        );
      }
    } catch (e) {
      print("DEBUG: ❌ Login exception caught: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred during login: ${e.toString()}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0FE),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 100),
                  const Text(
                    "Welcome Back",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        print("DEBUG: ElevatedButton onPressed called.");
                        _handleUsernamePasswordLogin();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Login',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                      );
                    },
                    child: const Text(
                      "Don't have an account? Sign Up",
                      style: TextStyle(
                        color: Colors.indigo,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/admin-login');
                    },
                    child: const Text(
                      "Login as Admin",
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
