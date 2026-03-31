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

/// Use case: Apply a blocking template to the native side
class ApplyBlockingTemplateUseCase {
  final AccessibilityRepository _repository;

  ApplyBlockingTemplateUseCase(this._repository);

  Future<void> call({
    required List<String> packages,
    required bool isWhitelist,
    String? taskName,
  }) {
    return _repository.applyBlockingTemplate(
      packages: packages,
      isWhitelist: isWhitelist,
      taskName: taskName,
    );
  }
}

/// Use case: Clear all blocking
class ClearBlockingUseCase {
  final AccessibilityRepository _repository;

  ClearBlockingUseCase(this._repository);

  Future<void> call() {
    return _repository.clearBlocking();
  }
}

/// Use case: Set the current task name on the blocking overlay
class SetCurrentTaskNameUseCase {
  final AccessibilityRepository _repository;

  SetCurrentTaskNameUseCase(this._repository);

  Future<void> call(String? taskName) {
    return _repository.setCurrentTaskName(taskName);
  }
}

/// Use case: Clear the current task name from the blocking overlay
class ClearCurrentTaskNameUseCase {
  final AccessibilityRepository _repository;

  ClearCurrentTaskNameUseCase(this._repository);

  Future<void> call() {
    return _repository.clearCurrentTaskName();
  }
}

