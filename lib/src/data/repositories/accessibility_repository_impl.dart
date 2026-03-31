import '../../domain/repositories/accessibility_repository.dart';
import '../datasources/accessibility_data_source.dart';

/// Concrete implementation of AccessibilityRepository
class AccessibilityRepositoryImpl implements AccessibilityRepository {
  final AccessibilityPlatformDataSource platformDataSource;

  AccessibilityRepositoryImpl({required this.platformDataSource});

  @override
  Future<bool> isAccessibilityEnabled() {
    return platformDataSource.isAccessibilityEnabled();
  }

  @override
  Future<void> requestAccessibility() {
    return platformDataSource.requestAccessibility();
  }

  @override
  Future<bool> canDrawOverlays() {
    return platformDataSource.canDrawOverlays();
  }

  @override
  Future<void> requestOverlayPermission() {
    return platformDataSource.requestOverlayPermission();
  }

  @override
  Stream<bool> watchAccessibilityStatus() {
    return platformDataSource.watchAccessibilityStatus();
  }

  @override
  Stream<String> watchAppOpeningEvents() {
    return platformDataSource.watchAppOpeningEvents();
  }

  @override
  Future<void> applyBlockingTemplate({
    required List<String> packages,
    required bool isWhitelist,
    String? taskName,
  }) {
    return platformDataSource.applyBlockingTemplate(
      packages: packages,
      isWhitelist: isWhitelist,
      taskName: taskName,
    );
  }

  @override
  Future<void> clearBlocking() {
    return platformDataSource.clearBlocking();
  }

  @override
  Future<void> setCurrentTaskName(String? taskName) {
    return platformDataSource.setCurrentTaskName(taskName);
  }

  @override
  Future<void> clearCurrentTaskName() {
    return platformDataSource.clearCurrentTaskName();
  }
}

