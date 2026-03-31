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

  /// Send blocking template to native side.
  /// [packages] is the list of app package names.
  /// [isWhitelist] controls whether the list is treated as a whitelist or blacklist.
  /// [taskName] is the current task name to display on the overlay.
  Future<void> applyBlockingTemplate({
    required List<String> packages,
    required bool isWhitelist,
    String? taskName,
  });

  /// Clear all blocking (empty list, blacklist mode, no task name).
  Future<void> clearBlocking();

  /// Set the current task name to be displayed on the blocking overlay.
  /// Pass `null` to clear the task name.
  Future<void> setCurrentTaskName(String? taskName);

  /// Clear the current task name from the blocking overlay.
  Future<void> clearCurrentTaskName();
}

