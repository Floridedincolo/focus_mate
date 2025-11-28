import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:focus_mate/pages/add_task.dart';
import 'package:focus_mate/pages/home.dart';
import 'pages/profile.dart';
import 'package:focus_mate/firebase_options.dart';
import 'package:block_app/block_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  final blockApp = BlockApp();

  await blockApp.initialize();

  // ✅ Pasul 1: cere permisiuni necesare
  final overlayGranted = await blockApp.requestOverlayPermission();

  print('Overlay permission granted: $overlayGranted');

  // ✅ Pasul 2: verifică aplicațiile instalate
  final apps = await blockApp.getInstalledApps(includeSystemApps: false);
  for (final app in apps) {
    print('App: ${app.appName} (${app.packageName})');
  }

  // Exemplu: blochează doar YouTube
  const packageToBlock = 'com.google.android.youtube';

  try {
    // ✅ Pasul 3: blochează o aplicație specifică (dacă permisiunile sunt OK)
    if ( overlayGranted) {
      final success=false; //= await blockApp.blockPackage(packageToBlock);
      print(success
          ? '✅ $packageToBlock blocată cu succes!'
          : '❌ Nu s-a putut bloca $packageToBlock.');
    } else {
      print('⚠️ Lipsesc permisiunile necesare pentru blocare.');
    }
  } catch (e) {
    print('❌ Eroare la blocare: $e');
  }

  // ✅ Pasul 4: rulează aplicația normal
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
