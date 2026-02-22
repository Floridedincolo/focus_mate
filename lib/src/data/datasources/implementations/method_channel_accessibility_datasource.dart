import 'package:flutter/services.dart';
import '../accessibility_data_source.dart';

/// MethodChannel implementation of AccessibilityPlatformDataSource
class MethodChannelAccessibilityDataSource
    implements AccessibilityPlatformDataSource {
  static const _accessibilityChannel =
      MethodChannel('focus_mate/accessibility');
  static const _accessibilityEventChannel =
      EventChannel('accessibility_events');

  @override
  Future<bool> isAccessibilityEnabled() async {
    try {
      final result = await _accessibilityChannel.invokeMethod<bool?>(
        'checkAccessibility',
      ).timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
      return result ?? false;
    } catch (e) {
      print('❌ Error checking accessibility: $e');
      return false;
    }
  }

  @override
  Future<void> requestAccessibility() async {
    try {
      await _accessibilityChannel.invokeMethod('promptAccessibility').timeout(
            const Duration(seconds: 2),
            onTimeout: () => null,
          );
    } catch (e) {
      print('❌ Error requesting accessibility: $e');
    }
  }

  @override
  Future<bool> canDrawOverlays() async {
    try {
      final result = await _accessibilityChannel.invokeMethod<bool?>(
        'canDrawOverlays',
      ).timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
      return result ?? false;
    } catch (e) {
      print('❌ Error checking overlay permission: $e');
      return false;
    }
  }

  @override
  Future<void> requestOverlayPermission() async {
    try {
      await _accessibilityChannel.invokeMethod('requestOverlayPermission').timeout(
            const Duration(seconds: 2),
            onTimeout: () => null,
          );
    } catch (e) {
      print('❌ Error requesting overlay permission: $e');
    }
  }

  @override
  Stream<bool> watchAccessibilityStatus() async* {
    try {
      // Emit current status immediately
      yield await isAccessibilityEnabled();

      // Poll for changes every 5 seconds with timeout
      while (true) {
        await Future.delayed(const Duration(seconds: 5));
        try {
          final status = await isAccessibilityEnabled();
          yield status;
        } catch (e) {
          print('⚠️ Error polling accessibility status: $e');
          // Continue polling
        }
      }
    } catch (e) {
      print('❌ Error in watchAccessibilityStatus: $e');
      yield false;
    }
  }

  @override
  Stream<String> watchAppOpeningEvents() {
    return _accessibilityEventChannel.receiveBroadcastStream().map((event) {
      return event.toString();
    }).handleError(
      (error) {
        print('⚠️ App opening events error: $error');
        // Return empty to prevent breaking the stream
      },
    );
  }
}

