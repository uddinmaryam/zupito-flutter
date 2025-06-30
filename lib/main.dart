import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:zupito/screens/map/map_screen.dart';
import 'firebase_options.dart';

import 'package:zupito/screens/login_screen.dart';
import 'package:zupito/screens/splash_screen.dart';
import 'package:zupito/screens/phone_number_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase already initialized: $e');
  }

  runApp(const MyApp());
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
        '/splash': (context) => SplashScreen(),
        '/login': (context) => LoginScreen(), // removed const if needed
        '/home': (context) => MapScreen(), // removed const
        '/phone': (context) => const PhoneNumberScreen(),
      },
    );
  }
}
