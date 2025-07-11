import 'package:flutter/material.dart';
import 'package:zupito/admin/admin_login_screen.dart';
import 'package:zupito/services/admin_api_service.dart'; // Import your AdminApiService
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

  // List of screens to display in the body
  final List<Widget> _screens = const [
    AdminDashboardScreen(),
    UserListScreen(),
    BikeListScreen(),
    StationListScreen(),
    RideListScreen(),
  ];

  // Titles for the AppBar
  final List<String> _titles = const [
    'Admin Dashboard', // More descriptive title
    'Manage Users',
    'Manage Bikes',
    'Manage Stations',
    'View Rides',
  ];

  // Function to handle admin logout
  Future<void> _logoutAdmin() async {
    try {
      await AdminApiService.logout(); // Use the logout method from AdminApiService
      // Navigate back to the login screen and remove all previous routes
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AdminLoginScreen()), // Assuming AdminLoginScreen is imported or defined
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      // Handle logout error, though it's less common for local storage deletion
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(color: Colors.white), // Title color
        ),
        backgroundColor: Colors.blueAccent, // AppBar color
        elevation: 0, // Remove shadow
        iconTheme: const IconThemeData(color: Colors.white), // Drawer icon color
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Custom Drawer Header
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.blueAccent,
                // Optional: You can add an image here
                // image: DecorationImage(
                //   image: AssetImage('assets/images/admin_banner.png'),
                //   fit: BoxFit.cover,
                // ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40, color: Colors.blueAccent),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Admin Panel',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Welcome Admin', // You could dynamically fetch admin username here
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            // Drawer Items for navigation
            _buildDrawerItem(Icons.dashboard, 'Dashboard', 0),
            _buildDrawerItem(Icons.people, 'Users', 1),
            _buildDrawerItem(Icons.pedal_bike, 'Bikes', 2),
            _buildDrawerItem(Icons.location_on, 'Stations', 3),
            _buildDrawerItem(Icons.history, 'Rides', 4),

            // Divider before logout
            const Divider(),

            // Logout item
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
              onTap: _logoutAdmin, // Call the private logout method
            ),
          ],
        ),
      ),
      body: _screens[_selectedIndex], // Display the selected screen
    );
  }

  // Helper method to build individual drawer items
  Widget _buildDrawerItem(IconData icon, String title, int index) {
    return ListTile(
      leading: Icon(icon, color: _selectedIndex == index ? Colors.blueAccent : Colors.grey[700]),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: _selectedIndex == index ? FontWeight.bold : FontWeight.normal,
          color: _selectedIndex == index ? Colors.blueAccent : Colors.black87,
        ),
      ),
      selected: _selectedIndex == index,
      selectedTileColor: Colors.blueAccent.withOpacity(0.1), // Highlight selected item
      onTap: () {
        setState(() => _selectedIndex = index);
        Navigator.pop(context); // Close the drawer after selection
      },
    );
  }
}

// You need to import AdminLoginScreen if it's in a different file
// Adjust path if necessary
