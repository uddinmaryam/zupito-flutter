import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/secure_storage_services.dart';
import 'login_screen.dart';

class ProtectedDataScreen extends StatefulWidget {
  const ProtectedDataScreen({super.key});

  @override
  State<ProtectedDataScreen> createState() => _ProtectedDataScreenState();
}

class _ProtectedDataScreenState extends State<ProtectedDataScreen> {
  final AuthService _authService = AuthService();
  final SecureStorageService _secureStorage = SecureStorageService();

  String? _protectedData;
  bool _isLoading = true;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _fetchProtectedData();
  }

  Future<void> _fetchProtectedData() async {
    setState(() {
      _isLoading = true;
    });

    final response = await _authService.getProtectedData();

    if (response != null && response.statusCode == 200) {
      setState(() {
        _protectedData = response.body;
        _isLoading = false;
      });
    } else {
      String errorMsg = 'Failed to load protected data.';
      if (response != null) {
        errorMsg += '\nStatus code: ${response.statusCode}';
        if (response.body.isNotEmpty) {
          errorMsg += '\nDetails: ${response.body}';
        }
      }
      setState(() {
        _protectedData = errorMsg;
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
    });

    await _secureStorage.deleteToken();

    setState(() {
      _isLoggingOut = false;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Protected Data'),
        actions: [
          IconButton(
            icon: _isLoggingOut ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.logout),
            onPressed: _isLoggingOut ? null : _logout,
          ),
        ],
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Text(_protectedData ?? 'No data'),
              ),
      ),
    );
  }
}
