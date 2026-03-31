import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_data_source.dart';
import '../../dtos/app_dto.dart';

/// SharedPreferences implementation of LocalBlockedAppsDataSource
class SharedPreferencesBlockedAppsDataSource
    implements LocalBlockedAppsDataSource {
  static const _blockedAppsKey = 'focus_mate_blocked_apps';
  static const _blockerChannel = MethodChannel('com.block_app/blocker');

  late SharedPreferences _prefs;
  final _controller = StreamController<List<BlockedAppDTO>>.broadcast();

  SharedPreferencesBlockedAppsDataSource();

  /// Initialize the data source
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  Future<List<BlockedAppDTO>> getBlockedApps() async {
    final jsonList = _prefs.getStringList(_blockedAppsKey) ?? [];
    return jsonList
        .map((json) => BlockedAppDTO.fromJson(json))
        .toList();
  }

  @override
  Stream<List<BlockedAppDTO>> watchBlockedApps() async* {
    // Emit current state immediately
    yield await getBlockedApps();
    // Then yield whenever setBlockedApps/remove/clear pushes an update
    yield* _controller.stream;
  }

  @override
  Future<void> saveBlockedApp(BlockedAppDTO app) async {
    final apps = await getBlockedApps();
    // Remove if exists and re-add
    apps.removeWhere((a) => a.packageName == app.packageName);
    apps.add(app);
    await setBlockedApps(apps);
  }

  @override
  Future<void> removeBlockedApp(String packageName) async {
    final apps = await getBlockedApps();
    apps.removeWhere((a) => a.packageName == packageName);
    await setBlockedApps(apps);
  }

  @override
  Future<void> setBlockedApps(List<BlockedAppDTO> apps) async {
    final jsonList = apps.map((app) => app.toJson()).toList();
    await _prefs.setStringList(_blockedAppsKey, jsonList);

    // Sync to Android native side so AppBlockService sees the blocked list
    try {
      final packageNames = apps.map((app) => app.packageName).toList();
      await _blockerChannel.invokeMethod('setBlockedApps', {'packages': packageNames});
    } catch (_) {
      // Platform call may fail on non-Android or in tests
    }

    _controller.add(apps);
  }

  @override
  Future<void> clearBlockedApps() async {
    await _prefs.remove(_blockedAppsKey);

    try {
      await _blockerChannel.invokeMethod('setBlockedApps', {'apps': <String>[]});
    } catch (_) {}

    _controller.add([]);
  }

  @override
  Future<bool> isAppBlocked(String packageName) async {
    final apps = await getBlockedApps();
    return apps.any((app) => app.packageName == packageName);
  }
}
