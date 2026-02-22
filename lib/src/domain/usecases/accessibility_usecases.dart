import '../repositories/accessibility_repository.dart';

/// Use case: Check if accessibility is enabled
class CheckAccessibilityUseCase {
  final AccessibilityRepository _repository;

  CheckAccessibilityUseCase(this._repository);

  Future<bool> call() {
    return _repository.isAccessibilityEnabled();
  }
}

/// Use case: Request accessibility permission
class RequestAccessibilityUseCase {
  final AccessibilityRepository _repository;

  RequestAccessibilityUseCase(this._repository);

  Future<void> call() {
    return _repository.requestAccessibility();
  }
}

/// Use case: Check if can draw overlays
class CheckOverlayPermissionUseCase {
  final AccessibilityRepository _repository;

  CheckOverlayPermissionUseCase(this._repository);

  Future<bool> call() {
    return _repository.canDrawOverlays();
  }
}

/// Use case: Request overlay permission
class RequestOverlayPermissionUseCase {
  final AccessibilityRepository _repository;

  RequestOverlayPermissionUseCase(this._repository);

  Future<void> call() {
    return _repository.requestOverlayPermission();
  }
}

/// Use case: Watch accessibility status changes
class WatchAccessibilityStatusUseCase {
  final AccessibilityRepository _repository;

  WatchAccessibilityStatusUseCase(this._repository);

  Stream<bool> call() {
    return _repository.watchAccessibilityStatus();
  }
}

/// Use case: Watch app opening events
class WatchAppOpeningEventsUseCase {
  final AccessibilityRepository _repository;

  WatchAppOpeningEventsUseCase(this._repository);

  Stream<String> call() {
    return _repository.watchAppOpeningEvents();
  }
}

