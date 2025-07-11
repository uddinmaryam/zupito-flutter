import 'package:flutter/material.dart';
import 'package:zupito/services/admin_api_service.dart';
import 'package:zupito/widgets/user_card.dart';
import 'package:zupito/models/user.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  List<User> _users =
      []; // This now unambiguously refers to your models/user.dart User
  bool _isLoading = true;
  String? _error; // Added error state

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _error = null; // Clear previous errors
    });
    try {
      final List<dynamic> userData = await AdminApiService.fetchUsers();
      setState(() {
        // Map the raw JSON data to a list of User objects
        _users = userData.map((json) => User.fromJson(json)).toList();
      });
    } catch (e) {
      setState(() {
        _error =
            'Failed to fetch users: ${e.toString().replaceFirst('Exception: ', '')}';
      });
      print('Error fetching users: $e'); // Log the error for debugging
      if (mounted) {
        // Check if the widget is still in the tree
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_error!)));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Removed AppBar as it's handled by AdminHomeScreen
    return RefreshIndicator(
      // Added RefreshIndicator for pull-to-refresh
      onRefresh: _fetchUsers,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _fetchUsers,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _users.isEmpty
          ? const Center(
              child: Text(
                'No users found.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return UserCard(user: user); // Pass the User object
              },
            ),
    );
  }
}
