import '../entities/installed_application.dart';

/// App manager repository - abstracts native app operations
abstract class AppManagerRepository {
  /// Get all installed applications
  Future<List<InstalledApplication>> getAllInstalledApps();

  /// Get only user apps (not system)
  Future<List<InstalledApplication>> getUserApps();

  /// Get app name by package name
  Future<String?> getAppName(String packageName);

  /// Get app icon by package name
  Future<List<int>?> getAppIcon(String packageName);
}

