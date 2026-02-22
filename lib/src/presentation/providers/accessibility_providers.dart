import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/accessibility_usecases.dart';
import '../../core/service_locator.dart';

/// Provider for CheckAccessibilityUseCase
final checkAccessibilityUseCaseProvider = Provider<CheckAccessibilityUseCase>(
  (ref) => getIt<CheckAccessibilityUseCase>(),
);

/// Provider for RequestAccessibilityUseCase
final requestAccessibilityUseCaseProvider =
    Provider<RequestAccessibilityUseCase>(
  (ref) => getIt<RequestAccessibilityUseCase>(),
);

/// Provider for CheckOverlayPermissionUseCase
final checkOverlayPermissionUseCaseProvider =
    Provider<CheckOverlayPermissionUseCase>(
  (ref) => getIt<CheckOverlayPermissionUseCase>(),
);

/// Provider for RequestOverlayPermissionUseCase
final requestOverlayPermissionUseCaseProvider =
    Provider<RequestOverlayPermissionUseCase>(
  (ref) => getIt<RequestOverlayPermissionUseCase>(),
);

/// Provider for WatchAccessibilityStatusUseCase
final watchAccessibilityStatusUseCaseProvider =
    Provider<WatchAccessibilityStatusUseCase>(
  (ref) => getIt<WatchAccessibilityStatusUseCase>(),
);

/// Provider for WatchAppOpeningEventsUseCase
final watchAppOpeningEventsUseCaseProvider =
    Provider<WatchAppOpeningEventsUseCase>(
  (ref) => getIt<WatchAppOpeningEventsUseCase>(),
);

/// Future provider for checking accessibility
final checkAccessibilityProvider = FutureProvider<bool>((ref) async {
  try {
    final usecase = ref.watch(checkAccessibilityUseCaseProvider);
    return await usecase();
  } catch (e) {
    print('❌ Error checking accessibility: $e');
    return false; // Safe default
  }
});

/// Future provider for checking overlay permission
final checkOverlayPermissionProvider = FutureProvider<bool>((ref) async {
  try {
    final usecase = ref.watch(checkOverlayPermissionUseCaseProvider);
    return await usecase();
  } catch (e) {
    print('❌ Error checking overlay: $e');
    return false; // Safe default
  }
});

/// Stream provider for accessibility status changes - NON-BLOCKING
final accessibilityStatusStreamProvider = StreamProvider<bool>((ref) async* {
  try {
    final usecase = ref.watch(watchAccessibilityStatusUseCaseProvider);
    yield* usecase();
  } catch (e) {
    print('❌ Error watching accessibility status: $e');
    yield false; // Safe default
  }
});

/// Stream provider for app opening events - OPTIONAL (can fail gracefully)
final appOpeningEventsStreamProvider = StreamProvider<String>((ref) async* {
  try {
    final usecase = ref.watch(watchAppOpeningEventsUseCaseProvider);
    yield* usecase();
  } catch (e) {
    print('⚠️ App opening events not available: $e');
    // Emit nothing - stream will show error state in UI
  }
});

/// Future provider for requesting accessibility
final requestAccessibilityProvider = FutureProvider<void>((ref) {
  final usecase = ref.watch(requestAccessibilityUseCaseProvider);
  return usecase();
});

/// Future provider for requesting overlay permission
final requestOverlayPermissionProvider = FutureProvider<void>((ref) {
  final usecase = ref.watch(requestOverlayPermissionUseCaseProvider);
  return usecase();
});

