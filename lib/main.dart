
import 'package:flutter/foundation.dart';
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

  // Catch Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('🔥 FlutterError: ${details.exceptionAsString()}');
    }
  };

  // Catch async errors not handled by Flutter
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('🔥 PlatformError: $error\n$stack');
    }
    return true;
  };

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Initialize dependency injection
    await setupServiceLocator();

    if (kDebugMode) {
      debugPrint('✅ Service Locator initialized');
    }
  } catch (e, stack) {
    if (kDebugMode) {
      debugPrint('🔥 Initialization failed: $e\n$stack');
    }
    // Run a minimal error app so the user sees something
    runApp(const _InitErrorApp());
    return;
  }

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

/// Minimal fallback app shown when Firebase or DI initialization fails.
class _InitErrorApp extends StatelessWidget {
  const _InitErrorApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
                SizedBox(height: 16),
                Text(
                  'Failed to start FocusMate',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Please check your internet connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

