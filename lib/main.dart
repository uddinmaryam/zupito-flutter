import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:zupito/admin/admin_home_screen.dart';
import 'package:zupito/admin/admin_login_screen.dart';
import 'package:zupito/screens/profile_screen.dart';
import 'package:zupito/screens/ride_history_screen.dart';
import 'firebase_options.dart';

import 'package:zupito/screens/map/map_screen.dart';
import 'package:zupito/screens/login_screen.dart';
import 'package:zupito/screens/splash_screen.dart';
import 'package:zupito/screens/phone_number_screen.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'package:zupito/admin/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase already initialized: $e');
  }

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
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Zupito',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.white,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: Colors.grey[900],
        dividerColor: Colors.white24,
        primarySwatch: Colors.indigo,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MapScreen(),
        '/phone': (context) => const PhoneNumberScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/history': (context) => const RideHistoryScreen(),
        '/admin': (context) => const AdminDashboardScreen(),
        '/admin-login': (context) => const AdminLoginScreen(),

        '/admin': (context) => const AdminHomeScreen(),

      },
    );
  }
}
