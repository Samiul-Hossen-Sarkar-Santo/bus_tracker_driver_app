import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:bus_tracker_driver_app/screens/loading.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'location_tracking',
        channelName: 'Location Tracking',
        channelDescription: 'Notification channel for location tracking',
        defaultColor: Colors.green[900],
        ledColor: Colors.green[900],
        playSound: true,
        enableVibration: true,
      ),
    ],
    debug: true,
  );
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully!');
  } catch (e) {
    print('Firebase initialization failed: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: const LoadingScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
