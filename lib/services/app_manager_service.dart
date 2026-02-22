import 'dart:typed_data';
import 'package:device_apps/device_apps.dart';

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
  static Future<List<InstalledApp>> getAllInstalledApps() async {
    List<Application> apps = await DeviceApps.getInstalledApplications(
      includeSystemApps: true,
      includeAppIcons: true,
      onlyAppsWithLaunchIntent: true,
    );

    print("📱 Total apps found: ${apps.length}");

    // Filtrăm TOATE aplicațiile care au icon valid (> 5 bytes)
    final validApps = apps.where((app) {
      if (app is ApplicationWithIcon) {
        final iconBytes = app.icon;
        return iconBytes.length > 5;
      }
      return false;
    }).toList();

    print(" Apps with valid icons: ${validApps.length}");

    return validApps.map((app) {
      bool hasIcon = app is ApplicationWithIcon;

      return InstalledApp(
        appName: app.appName,
        packageName: app.packageName,
        isSystemApp: app.systemApp,
        iconBytes: hasIcon ? (app).icon : null,
      );
    }).toList();
  }
}
