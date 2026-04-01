import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../usage_stats_datasource.dart';

class MethodChannelUsageStatsDataSource implements UsageStatsDataSource {
  static const _channel = MethodChannel('com.example.focus_mate/usage_stats');

  @override
  Future<bool> hasUsagePermission() async {
    try {
      final result = await _channel.invokeMethod<bool?>('hasUsagePermission')
          .timeout(const Duration(seconds: 2), onTimeout: () => false);
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error checking usage permission: $e');
      return false;
    }
  }

  @override
  Future<void> requestUsagePermission() async {
    try {
      await _channel.invokeMethod('requestUsagePermission')
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error requesting usage permission: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getUsageStats({int days = 1}) async {
    try {
      final result = await _channel
          .invokeMethod<Map>('getUsageStats', {'days': days})
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
      if (result == null) return _emptyStats();
      return Map<String, dynamic>.from(result);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting usage stats: $e');
      return _emptyStats();
    }
  }

  Map<String, dynamic> _emptyStats() => {
        'totalScreenTimeMinutes': 0,
        'hourlyUsage': List<int>.filled(24, 0),
        'topApps': <Map<String, dynamic>>[],
        // TODO(kotlin): Wire these from AppBlockService tracking
        'focusTimeMinutes': 0,
        'preventedDistractions': 0,
      };
}
