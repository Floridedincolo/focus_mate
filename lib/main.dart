import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:focus_mate/pages/home.dart';
import 'package:focus_mate/pages/add_task.dart';
import 'pages/profile.dart';
import 'package:focus_mate/firebase_options.dart';
import 'package:flutter/services.dart'; // pentru EventChannel

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inițializează Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // ✅ Ascultă evenimentele de la AccessibilityService
  final accessibilityChannel = EventChannel('accessibility_events');
  accessibilityChannel.receiveBroadcastStream().listen((event) {
    final packageName = event.toString();
    print('📣 App opened: $packageName');

    // Exemplu: blocare YouTube
    if (packageName == 'com.google.android.youtube') {
      print('⚠️ Trebuie blocată YouTube!');

      // Aici poți afișa overlay-ul tău personalizat
      // showOverlay();
    }
  }, onError: (error) {
    print('❌ Eroare la evenimentele Accessibility: $error');
  });

  // Rulează aplicația normal
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Home(),
      routes: {
        '/profile': (context) => Profile(),
        '/add_task': (context) => AddTaskMenu(),
      },
    ),
  );
}
