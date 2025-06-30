import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'package:zupito/screens/login_screen.dart';
import 'package:zupito/screens/splash_screen.dart';
import 'package:zupito/screens/phone_number_screen.dart';
import 'package:zupito/screens/map/map_screen.dart';

// 🔔 Global notification plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase already initialized: $e');
  }

  await initializeNotifications(); // 🔔 Initialize local notifications

  runApp(const MyApp());
}

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings settings = InitializationSettings(
    android: androidSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(settings);
}

// 🔔 Function to show local notification
Future<void> showUnlockNotification(String bikeName) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'zupito_channel',
    'Zupito Notifications',
    channelDescription: 'Channel for Zupito unlock notifications',
    importance: Importance.max,
    priority: Priority.high,
  );

  const NotificationDetails platformDetails = NotificationDetails(
    android: androidDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    0,
    'Bike Unlocked',
    'You tapped to unlock $bikeName',
    platformDetails,
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
        '/splash': (context) => SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MapScreen(),
        '/phone': (context) => const PhoneNumberScreen(),
      },
    );
  }
}
