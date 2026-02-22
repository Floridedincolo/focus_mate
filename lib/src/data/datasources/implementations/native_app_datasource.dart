import 'package:flutter/services.dart';
import '../app_data_source.dart';
import '../../dtos/app_dto.dart';

/// MethodChannel implementation for RemoteAppDataSource (native app management)
class NativeMethodChannelAppDataSource implements RemoteAppDataSource {
  static const _appChannel =
      MethodChannel('com.example.focus_mate/apps');

  @override
  Future<List<InstalledApplicationDTO>> getAllInstalledApps() async {
    try {
      final result = await _appChannel.invokeMethod<List<dynamic>>(
        'getAllInstalledApps',
      );

      if (result == null) return [];

      return result
          .cast<Map<dynamic, dynamic>>()
          .map((data) => InstalledApplicationDTO.fromMap(data))
          .toList();
    } catch (e) {
      print('❌ Error getting installed apps: $e');
      return [];
    }
  }

  @override
  Future<List<InstalledApplicationDTO>> getUserApps() async {
    try {
      final result = await _appChannel.invokeMethod<List<dynamic>>(
        'getUserApps',
      );

      if (result == null) return [];

      return result
          .cast<Map<dynamic, dynamic>>()
          .map((data) => InstalledApplicationDTO.fromMap(data))
          .toList();
    } catch (e) {
      print('❌ Error getting user apps: $e');
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
      print('❌ Error getting app name: $e');
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
      print('❌ Error getting app icon: $e');
      return null;
    }
  }
}

