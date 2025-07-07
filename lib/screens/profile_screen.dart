import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:zupito/services/api_service.dart';
import 'package:zupito/services/secure_storage_services.dart';
import 'package:zupito/models/user.dart';
import 'package:provider/provider.dart';
import 'package:zupito/providers/theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SecureStorageService _secureStorage = SecureStorageService();
  UserProfile? _user;
  int _totalRides = 0;
  String _totalDistance = '0 km';
  int _totalPenalty = 0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final data = await _secureStorage.readUser();
    if (data != null) {
      final jsonData = jsonDecode(data);
      final user = UserProfile.fromJson(jsonData);
      setState(() => _user = user);

      try {
        final summary = await ApiService().fetchRideSummary(user.id.toString());
        setState(() {
          _totalRides = summary['totalRides'];
          _totalDistance = summary['totalDistance'];
          _totalPenalty = summary['totalPenalty'];
        });
      } catch (e) {
        debugPrint("❌ Error fetching ride summary: $e");
      }
    }
  }

  void _logout() async {
    await _secureStorage.clear();
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      '/login',
    ); // Update this route as needed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.indigo,
      ),
      body: _user == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.account_circle,
                        size: 80,
                        color: Colors.indigo,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _user!.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _user!.email,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.bar_chart),
                        title: const Text('Total Rides'),
                        trailing: Text('$_totalRides'),
                        onTap: () => Navigator.pushNamed(context, '/history'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.directions_bike),
                        title: const Text('Total Distance'),
                        trailing: Text(_totalDistance),
                        onTap: () => Navigator.pushNamed(context, '/history'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.warning),
                        title: const Text('Total Penalty'),
                        trailing: Text('Rs. $_totalPenalty'),
                        onTap: () => Navigator.pushNamed(context, '/history'),
                      ),
                     
                      ListTile(
                        leading: const Icon(Icons.nightlight_round),
                        title: const Text("Dark Mode"),
                        trailing: Switch(
                          value: Provider.of<ThemeProvider>(context).isDarkMode,
                          onChanged: (val) {
                            Provider.of<ThemeProvider>(
                              context,
                              listen: false,
                            ).toggleTheme(val);
                          },
                        ),
                      ),

                      const Divider(),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, color: Colors.white),
                        label: const Text('Logout'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
