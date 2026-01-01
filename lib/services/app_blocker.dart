import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class AppBlockerService {
  static const MethodChannel _channel =
  MethodChannel('app.blocked.channel');

  // Stream sau callback pentru aplicațiile blocate
  final void Function(String packageName) onAppOpened;

  AppBlockerService({required this.onAppOpened}) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == "appOpened") {
        final String packageName = call.arguments;
        onAppOpened(packageName);
      }
    });
  }
}
