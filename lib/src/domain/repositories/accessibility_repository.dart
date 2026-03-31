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

  /// Apply a blocking template to the native side
  Future<void> applyBlockingTemplate({
    required List<String> packages,
    required bool isWhitelist,
    String? taskName,
  });

  /// Clear all blocking
  Future<void> clearBlocking();

  /// Set the current task name to display on the blocking overlay
  Future<void> setCurrentTaskName(String? taskName);

  /// Clear the current task name from the blocking overlay
  Future<void> clearCurrentTaskName();
}

