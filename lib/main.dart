import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'src/core/service_locator.dart';
import 'src/presentation/pages/main_page.dart';
import 'src/presentation/pages/focus_page.dart';
import 'src/presentation/pages/home.dart';
import 'src/presentation/pages/add_task.dart';
import 'src/presentation/pages/stats_page.dart';
import 'src/presentation/pages/profile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Initialize dependency injection
  await setupServiceLocator();

  print('✅ Service Locator initialized');

  // Run app
  runApp(const ProviderScope(child: FocusMateApp()));
}

class FocusMateApp extends StatelessWidget {
  const FocusMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    );
  }
}

