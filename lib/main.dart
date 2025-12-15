import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:focus_mate/pages/add_task.dart';
import 'package:focus_mate/pages/home.dart';
import 'package:focus_mate/pages/permissions_page.dart';
import 'package:focus_mate/pages/test_blocking_page.dart';
import 'pages/profile.dart';
import 'package:focus_mate/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Home(),
      routes: {
        '/profile': (context) => Profile(),
        '/add_task': (context) => AddTaskMenu(),
        '/permissions': (context) => const PermissionsPage(),
        '/test_blocking': (context) => const TestBlockingPage(),
      },
    ),
  );
}
