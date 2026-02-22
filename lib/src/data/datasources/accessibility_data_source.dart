/// Platform-level accessibility operations
abstract class AccessibilityPlatformDataSource {
  /// Check if accessibility service is enabled
  Future<bool> isAccessibilityEnabled();

  /// Request user to enable accessibility
  Future<void> requestAccessibility();

  /// Check if can draw overlays
  Future<bool> canDrawOverlays();

  /// Request overlay permission
  Future<void> requestOverlayPermission();

  /// Watch accessibility status
  Stream<bool> watchAccessibilityStatus();

  /// Watch app opening events
  Stream<String> watchAppOpeningEvents();
}

