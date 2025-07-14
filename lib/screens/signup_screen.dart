import 'dart:io'; // For File
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // For image picking
import '../services/auth_service.dart'; // Ensure this path is correct

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _citizenshipNumberController =
      TextEditingController(); // New controller

  File? _citizenshipImage; // To store the selected image file
  final ImagePicker _picker = ImagePicker(); // Image picker instance

  final AuthService authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _citizenshipNumberController.dispose(); // Dispose new controller
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _citizenshipImage = File(pickedFile.path);
      });
      _showSnackBar('Citizenship image selected!');
    } else {
      _showSnackBar('No image selected.');
    }
  }

  Future<void> _handleSignup() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final phone = _phoneController.text.trim();
    final citizenshipNumber = _citizenshipNumberController.text.trim();

    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        phone.isEmpty ||
        citizenshipNumber.isEmpty ||
        _citizenshipImage == null) {
      _showSnackBar('Please fill all fields and select a citizenship image.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await authService.signup(
        username: username,
        email: email,
        password: password,
        phone: phone,
        citizenshipNumber: citizenshipNumber,
        citizenshipImage: _citizenshipImage!, // Pass the File object
      );
      if (!mounted) return; // Check mounted before showing snackbar/navigating

      if (success) {
        _showSnackBar('Signup successful! Please login.');
        Navigator.pop(context); // Go back to login screen
      } else {
        _showSnackBar('Signup failed. Try again.');
      }
    } catch (e) {
      _showSnackBar('Error during signup: $e');
      debugPrint('Signup error: $e'); // Print detailed error to console
    } finally {
      if (!mounted) return; // Check mounted before setState
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return; // Ensure widget is still in tree
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0FE), // matching login screen
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              const Text(
                'Welcome to Zupito!',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),

              // Username
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Password
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Phone Number
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Citizenship Number (New)
              TextField(
                controller: _citizenshipNumberController,
                keyboardType:
                    TextInputType.number, // Assuming numeric or alphanumeric
                decoration: const InputDecoration(
                  labelText: 'Citizenship Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Citizenship Image Picker (New)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _citizenshipImage == null
                            ? 'No citizenship image selected'
                            : 'Image selected: ${_citizenshipImage!.path.split('/').last}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _citizenshipImage == null
                              ? Colors.grey[700]
                              : Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Pick Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors
                            .indigo
                            .shade100, // Lighter indigo for this button
                        foregroundColor: Colors.indigo,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Sign Up Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Sign Up',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Login Text Button
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Already have an account? Login',
                  style: TextStyle(color: Colors.indigo),
                ),
              ),
              const SizedBox(height: 30), // Add some padding at the bottom
            ],
          ),
        ),
      ),
    );
  }
}
