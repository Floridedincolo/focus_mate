import 'package:block_app/block_app.dart';
import 'package:flutter/material.dart';

// Re-export AppModel for convenience
export 'package:block_app/block_app.dart' show AppModel;

class AppBlockerService {
  static final AppBlockerService _instance = AppBlockerService._internal();
  factory AppBlockerService() => _instance;
  AppBlockerService._internal();

  final BlockApp _blockApp = BlockApp();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await _blockApp.initialize();
    _initialized = true;
  }

  /// Check if overlay permission is granted
  Future<bool> hasOverlayPermission() async {
    await initialize();
    final perms = await _blockApp.checkPermissions();
    return perms['hasOverlayPermission'] ?? false;
  }

  /// Request overlay permission (opens system settings)
  Future<void> requestOverlayPermission() async {
    await initialize();
    await _blockApp.requestOverlayPermission();
  }

  /// Check if usage stats permission is granted
  Future<bool> hasUsageStatsPermission() async {
    await initialize();
    final perms = await _blockApp.checkPermissions();
    return perms['hasUsageStatsPermission'] ?? false;
  }

  /// Request usage stats permission (opens system settings)
  Future<void> requestUsageStatsPermission() async {
    await initialize();
    await _blockApp.requestUsageStatsPermission();
  }

  /// Check if all required permissions are granted
  Future<bool> hasAllPermissions() async {
    final hasOverlay = await hasOverlayPermission();
    final hasUsage = await hasUsageStatsPermission();
    return hasOverlay && hasUsage;
  }

  /// Get list of installed apps
  Future<List<AppModel>> getInstalledApps({bool includeSystemApps = false}) async {
    await initialize();
    return await _blockApp.getInstalledApps(includeSystemApps: includeSystemApps);
  }

  /// Block a specific app by package name
  Future<bool> blockApp(String packageName) async {
    await initialize();
    try {
      final success = await _blockApp.blockApp(packageName);
      if (success) {
        // Ensure the blocking service is running
        await _blockApp.startBlockingService();
      }
      return success;
    } catch (e) {
      debugPrint('Error blocking app $packageName: $e');
      return false;
    }
  }

  /// Unblock a specific app
  Future<bool> unblockApp(String packageName) async {
    await initialize();
    try {
      return await _blockApp.unblockApp(packageName);
    } catch (e) {
      debugPrint('Error unblocking app $packageName: $e');
      return false;
    }
  }

  /// Get list of currently blocked apps
  Future<List<String>> getBlockedApps() async {
    await initialize();
    return await _blockApp.getBlockedApps();
  }

  /// Block multiple apps at once
  Future<void> blockApps(List<String> packageNames) async {
    for (final packageName in packageNames) {
      await blockApp(packageName);
    }
  }

  /// Unblock all apps
  Future<void> unblockAllApps() async {
    final blockedApps = await getBlockedApps();
    for (final packageName in blockedApps) {
      await unblockApp(packageName);
    }
  }

  /// Start the blocking service
  Future<bool> startBlockingService() async {
    await initialize();
    try {
      return await _blockApp.startBlockingService();
    } catch (e) {
      debugPrint('Error starting blocking service: $e');
      return false;
    }
  }

  /// Stop the blocking service
  Future<bool> stopBlockingService() async {
    await initialize();
    try {
      return await _blockApp.stopBlockingService();
    } catch (e) {
      debugPrint('Error stopping blocking service: $e');
      return false;
    }
  }
}

