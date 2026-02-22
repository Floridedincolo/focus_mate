import '../dtos/app_dto.dart';

/// Remote data source for app management
abstract class RemoteAppDataSource {
  /// Get all installed apps from native code
  Future<List<InstalledApplicationDTO>> getAllInstalledApps();

  /// Get user apps (non-system)
  Future<List<InstalledApplicationDTO>> getUserApps();

  /// Get app name by package
  Future<String?> getAppName(String packageName);

  /// Get app icon by package
  Future<InstalledApplicationDTO?> getAppIcon(String packageName);
}

/// Local data source for blocked apps
abstract class LocalBlockedAppsDataSource {
  /// Get blocked apps from local storage
  Future<List<BlockedAppDTO>> getBlockedApps();

  /// Watch blocked apps changes
  Stream<List<BlockedAppDTO>> watchBlockedApps();

  /// Save blocked app
  Future<void> saveBlockedApp(BlockedAppDTO app);

  /// Remove blocked app
  Future<void> removeBlockedApp(String packageName);

  /// Set all blocked apps
  Future<void> setBlockedApps(List<BlockedAppDTO> apps);

  /// Clear blocked apps
  Future<void> clearBlockedApps();

  /// Check if app is blocked
  Future<bool> isAppBlocked(String packageName);
}

