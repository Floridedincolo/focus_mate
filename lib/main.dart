import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'src/core/service_locator.dart';
import 'src/presentation/pages/main_page.dart';
import 'src/presentation/pages/focus_page.dart';
import 'src/presentation/pages/home.dart';
import 'src/presentation/pages/add_task.dart';
import 'src/presentation/pages/stats/stats_page.dart';
import 'src/presentation/pages/profile.dart';
import 'src/presentation/pages/login_page.dart';
import 'src/presentation/pages/schedule_import/schedule_import_page.dart';
import 'src/presentation/pages/setup_profile_page.dart';
import 'src/presentation/pages/friends/friends_page.dart';
import 'src/presentation/pages/friends/plan_meeting_page.dart';
import 'src/presentation/pages/full_schedule_page.dart';
import 'src/domain/repositories/user_location_repository.dart';
import 'src/domain/repositories/notification_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('PlatformError: $error\n$stack');
    }
    return true;
  };

  try {
    await dotenv.load(fileName: ".env");

    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    await setupServiceLocator();
    await getIt<NotificationRepository>().initialize();

    if (kDebugMode) {
      debugPrint('Service Locator initialized');
    }
  } catch (e, stack) {
    if (kDebugMode) {
      debugPrint('Initialization failed: $e\n$stack');
    }
    runApp(const _InitErrorApp());
    return;
  }

  runApp(const ProviderScope(child: FocusMateApp()));
}

class FocusMateApp extends StatelessWidget {
  const FocusMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const _AuthGate(),
      routes: {
        '/profile': (context) => const Profile(),
        '/add_task': (context) => const AddTaskMenu(),
        '/focus_page': (context) => const FocusPage(),
        '/home': (context) => const Home(),
        '/stats': (context) => const StatsPage(),
        '/main': (context) => const MainPage(),
        '/import-schedule': (context) => const ScheduleImportPage(),
        '/login': (context) => const LoginPage(),
        '/friends': (context) => const FriendsPage(),
        '/plan-meeting': (context) => const PlanMeetingPage(),
        '/full-schedule': (context) => const FullSchedulePage(),
      },
    );
  }
}

/// Listens to Firebase Auth state and shows [LoginPage] or checks onboarding.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  Future<void> _syncProfile(User user) async {
    try {
      final name = user.displayName ?? user.email ?? 'User';
      final data = <String, dynamic>{
        'displayName': name,
        'displayNameLower': name.toLowerCase(),
        if (user.photoURL != null) 'photoUrl': user.photoURL,
        if (user.email != null) 'email': user.email,
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('Profile sync failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D0D0D),
            body: Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            ),
          );
        }

        if (snapshot.hasData) {
          _syncProfile(snapshot.data!);
          return const _OnboardingGate();
        }

        return const LoginPage();
      },
    );
  }
}

/// Checks whether the user has completed initial location setup.
class _OnboardingGate extends StatelessWidget {
  const _OnboardingGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: getIt<UserLocationRepository>().hasCompletedSetup(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D0D0D),
            body: Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            ),
          );
        }
        if (snap.data == true) return const MainPage();
        return const SetupProfilePage();
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
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
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
