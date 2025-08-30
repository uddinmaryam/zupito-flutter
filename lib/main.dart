import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Screens & Services
import 'package:zupito/screens/splash_screen.dart';
import 'package:zupito/screens/login_screen.dart';
import 'package:zupito/screens/map/map_screen.dart';
import 'package:zupito/screens/profile_screen.dart';
import 'package:zupito/screens/ride_history_screen.dart';
import 'package:zupito/screens/phone_number_screen.dart';
import 'package:zupito/screens/pending_users_screen.dart';

// Admin Screens
import 'package:zupito/admin/admin_home_screen.dart';
import 'package:zupito/admin/admin_login_screen.dart';
import 'package:zupito/admin/user_list_screen.dart';
import 'package:zupito/admin/bike_list_screen.dart';
import 'package:zupito/admin/station_list_screen.dart';
import 'package:zupito/admin/ride_list_screen.dart';

// Theme
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zupito',
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MapScreen(),
        '/phone': (context) => const PhoneNumberScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/history': (context) => const RideHistoryScreen(),
        '/admin-login': (context) => const AdminLoginScreen(),
        '/admin': (context) => const AdminHomeScreen(),
        '/users': (context) => const UserListScreen(),
        '/bikes': (context) => const BikeListScreen(),
        '/stations': (context) => const StationListScreen(),
        '/rides': (context) => const RideListScreen(),
        '/pending-users': (context) => const PendingUsersScreen(),
      },
    );
  }
}
