/// Accessibility service repository
abstract class AccessibilityRepository {
  /// Check if accessibility service is enabled
  Future<bool> isAccessibilityEnabled();

  /// Request user to enable accessibility
  Future<void> requestAccessibility();

  /// Check if overlay permission is available
  Future<bool> canDrawOverlays();

  /// Request overlay permission
  Future<void> requestOverlayPermission();

  /// Watch accessibility status changes
  Stream<bool> watchAccessibilityStatus();

  /// Watch app opening events
  Stream<String> watchAppOpeningEvents();
}

