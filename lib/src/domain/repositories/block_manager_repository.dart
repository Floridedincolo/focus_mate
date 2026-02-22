import '../entities/blocked_app.dart';

/// Block manager repository - manages blocked applications
abstract class BlockManagerRepository {
  /// Get list of currently blocked apps
  Future<List<BlockedApp>> getBlockedApps();

  /// Watch blocked apps as a stream
  Stream<List<BlockedApp>> watchBlockedApps();

  /// Add an app to the block list
  Future<void> addBlockedApp(BlockedApp app);

  /// Remove an app from the block list
  Future<void> removeBlockedApp(String packageName);

  /// Set entire block list
  Future<void> setBlockedApps(List<BlockedApp> apps);

  /// Clear all blocked apps
  Future<void> clearBlockedApps();

  /// Check if an app is blocked
  Future<bool> isAppBlocked(String packageName);
}

