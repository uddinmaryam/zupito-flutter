import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dashboard_screen.dart';
import 'user_list_screen.dart';
import 'bike_list_screen.dart';
import 'station_list_screen.dart';
import 'ride_list_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    AdminDashboardScreen(),
    UserListScreen(),
    BikeListScreen(),
    StationListScreen(),
    RideListScreen(),
  ];

  final List<String> _titles = [
    'Dashboard',
    'Users',
    'Bikes',
    'Stations',
    'Rides',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_selectedIndex])),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.indigo),
              child: Text(
                'Admin Panel',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            _buildDrawerItem(Icons.dashboard, 'Dashboard', 0),
            _buildDrawerItem(Icons.people, 'Users', 1),
            _buildDrawerItem(Icons.pedal_bike, 'Bikes', 2),
            _buildDrawerItem(Icons.location_on, 'Stations', 3),
            _buildDrawerItem(Icons.history, 'Rides', 4),

            // ✅ Logout item
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await logoutAdmin();
                Navigator.pushReplacementNamed(context, '/admin-login');
              },
            ),
          ],
        ),
      ),
      body: _screens[_selectedIndex],
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, int index) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: _selectedIndex == index,
      onTap: () {
        setState(() => _selectedIndex = index);
        Navigator.pop(context); // Close drawer
      },
    );
  }

  Future<void> logoutAdmin() async {
    final storage = FlutterSecureStorage();
    await storage.delete(key: 'admin_token');
  }
}
