import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../app_data_source.dart';
import '../../dtos/app_dto.dart';

/// MethodChannel implementation for RemoteAppDataSource (native app management)
class NativeMethodChannelAppDataSource implements RemoteAppDataSource {
  static const _appChannel =
      MethodChannel('com.example.focus_mate/apps');

  // Cache to avoid expensive native calls + Base64 icon encoding on every open
  List<InstalledApplicationDTO>? _allAppsCache;
  List<InstalledApplicationDTO>? _userAppsCache;
  DateTime? _allAppsCacheTime;
  DateTime? _userAppsCacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  bool _isCacheValid(DateTime? cacheTime) =>
      cacheTime != null && DateTime.now().difference(cacheTime) < _cacheDuration;

  @override
  Future<List<InstalledApplicationDTO>> getAllInstalledApps() async {
    if (_allAppsCache != null && _isCacheValid(_allAppsCacheTime)) {
      return _allAppsCache!;
    }
    try {
      final result = await _appChannel.invokeMethod<List<dynamic>>(
        'getAllInstalledApps',
      );

      if (result == null) return [];

      _allAppsCache = result
          .cast<Map<dynamic, dynamic>>()
          .map((data) => InstalledApplicationDTO.fromMap(data))
          .toList();
      _allAppsCacheTime = DateTime.now();
      return _allAppsCache!;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting installed apps: $e');
      return [];
    }
  }

  @override
  Future<List<InstalledApplicationDTO>> getUserApps() async {
    if (_userAppsCache != null && _isCacheValid(_userAppsCacheTime)) {
      return _userAppsCache!;
    }
    try {
      final result = await _appChannel.invokeMethod<List<dynamic>>(
        'getUserApps',
      );

      if (result == null) return [];

      _userAppsCache = result
          .cast<Map<dynamic, dynamic>>()
          .map((data) => InstalledApplicationDTO.fromMap(data))
          .toList();
      _userAppsCacheTime = DateTime.now();
      return _userAppsCache!;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting user apps: $e');
      return [];
    }
  }

  @override
  Future<String?> getAppName(String packageName) async {
    try {
      return await _appChannel.invokeMethod<String?>(
        'getAppName',
        {'packageName': packageName},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting app name: $e');
      return null;
    }
  }

  @override
  Future<InstalledApplicationDTO?> getAppIcon(String packageName) async {
    try {
      final result = await _appChannel.invokeMethod<Map<dynamic, dynamic>?>(
        'getAppIcon',
        {'packageName': packageName},
      );

      if (result == null) return null;
      return InstalledApplicationDTO.fromMap(result);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting app icon: $e');
      return null;
    }
  }
}
