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
      await _accessibilityChannel.invokeMethod('promptAccessibility');
    } catch (e) {
      print('❌ Error requesting accessibility: $e');
    }
  }

  @override
  Future<bool> canDrawOverlays() async {
    try {
      final result = await _accessibilityChannel.invokeMethod<bool?>(
        'canDrawOverlays',
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
      await _accessibilityChannel.invokeMethod('requestOverlayPermission');
    } catch (e) {
      print('❌ Error requesting overlay permission: $e');
    }
  }

  @override
  Stream<bool> watchAccessibilityStatus() async* {
    // Emit current status immediately
    yield await isAccessibilityEnabled();

    // Poll for changes every 2 seconds
    while (true) {
      await Future.delayed(const Duration(seconds: 2));
      yield await isAccessibilityEnabled();
    }
  }

  @override
  Stream<String> watchAppOpeningEvents() {
    return _accessibilityEventChannel.receiveBroadcastStream().map((event) {
      return event.toString();
    });
  }
}

