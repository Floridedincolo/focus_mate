// Acest fișier oferă o interfață simplă pentru a comunica cu sistemul nativ de blocare
import 'package:flutter/services.dart';

class BlockAppManager {
  static const MethodChannel _channel = MethodChannel('com.block_app/blocker');

  /// Adaugă o aplicație în lista de blocare
  static Future<void> addAppToBlockList(String packageName) async {
    try {
      await _channel.invokeMethod('addBlockedApp', {'package': packageName});
    } catch (e) {
      print('❌ Error adding app to block list: $e');
    }
  }

  /// Șterge o aplicație din lista de blocare
  static Future<void> removeAppFromBlockList(String packageName) async {
    try {
      await _channel.invokeMethod('removeBlockedApp', {'package': packageName});
    } catch (e) {
      print('❌ Error removing app from block list: $e');
    }
  }

  /// Șterge toate aplicațiile din lista de blocare
  static Future<void> clearBlockList() async {
    try {
      await _channel.invokeMethod('clearBlockList');
    } catch (e) {
      print('❌ Error clearing block list: $e');
    }
  }

  /// Setează lista completă de aplicații blocate
  static Future<void> setBlockedApps(List<String> packageNames) async {
    try {
      await _channel.invokeMethod('setBlockedApps', {'packages': packageNames});
    } catch (e) {
      print('❌ Error setting blocked apps: $e');
    }
  }
}

