import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:focus_mate/pages/focus_page.dart';
import 'package:focus_mate/pages/home.dart';
import 'package:focus_mate/pages/add_task.dart';
import 'package:focus_mate/pages/main_page.dart';
import 'package:focus_mate/pages/stats_page.dart';
import 'pages/profile.dart';
import 'package:focus_mate/firebase_options.dart';
import 'package:flutter/services.dart'; // pentru EventChannel
import 'services/accessibility_service.dart'; // ✅ Import nou

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

  // ✅ Verifică Accessibility Service la pornire
  final isAccessibilityEnabled = await AccessibilityService.isEnabled();
  if (!isAccessibilityEnabled) {
    print('⚠️ Accessibility Service NU este activ!');
    // Se va deschide automat setările când se apasă butonul din UI
  } else {
    print('✅ Accessibility Service este ACTIV și funcțional!');
  }

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
      home: const MainPage(),
      routes: {
        '/profile': (context) => const Profile(),
        '/add_task': (context) => const AddTaskMenu(),
        '/focus_page': (context) => const FocusPage(),
        '/home': (context) => const Home(),
        '/stats': (context) => const StatsPage(),
        '/main': (context) => const MainPage(),
      },
    ),
  );
}
