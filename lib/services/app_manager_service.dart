import 'dart:typed_data';
import 'dart:convert' show base64;
import 'package:flutter/services.dart';

class InstalledApp {
  final String appName;
  final String packageName;
  final bool isSystemApp;
  final Uint8List? iconBytes;

  InstalledApp({
    required this.appName,
    required this.packageName,
    required this.isSystemApp,
    this.iconBytes,
  });
}

class AppManagerService {
  static const platform = MethodChannel('com.example.focus_mate/apps');

  static Future<List<InstalledApp>> getAllInstalledApps() async {
    try {
      final result = await platform.invokeMethod<List<dynamic>>(
        'getAllInstalledApps',
      );

      if (result == null) {
        print("❌ No apps returned from native code");
        return [];
      }

      print("📱 Total apps found: ${result.length}");

      final apps = result.cast<Map<dynamic, dynamic>>().map((appData) {
        final iconBase64 = appData['iconBase64'] as String?;
        Uint8List? iconBytes;

        if (iconBase64 != null && iconBase64.isNotEmpty) {
          try {
            iconBytes = Uint8List.fromList(base64.decode(iconBase64));
          } catch (e) {
            print("⚠️ Failed to decode icon for ${appData['appName']}: $e");
          }
        }

        return InstalledApp(
          appName: appData['appName'] as String? ?? 'Unknown',
          packageName: appData['packageName'] as String? ?? '',
          isSystemApp: appData['isSystemApp'] as bool? ?? false,
          iconBytes: iconBytes,
        );
      }).toList();

      // Filter apps with valid icons (> 5 bytes)
      final validApps = apps
          .where((app) => app.iconBytes != null && app.iconBytes!.length > 5)
          .toList();

      print("✅ Apps with valid icons: ${validApps.length}");
      return validApps;
    } catch (e) {
      print("❌ Error getting installed apps: $e");
      return [];
    }
  }
}
