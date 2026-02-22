import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/blocked_app.dart';
import '../../domain/entities/installed_application.dart';
import '../../domain/usecases/app_usecases.dart';
import '../../core/service_locator.dart';

/// Provider for GetAllAppsUseCase
final getAllAppsUseCaseProvider = Provider<GetAllAppsUseCase>(
  (ref) => getIt<GetAllAppsUseCase>(),
);

/// Provider for GetUserAppsUseCase
final getUserAppsUseCaseProvider = Provider<GetUserAppsUseCase>(
  (ref) => getIt<GetUserAppsUseCase>(),
);

/// Provider for GetBlockedAppsUseCase
final getBlockedAppsUseCaseProvider = Provider<GetBlockedAppsUseCase>(
  (ref) => getIt<GetBlockedAppsUseCase>(),
);

/// Provider for WatchBlockedAppsUseCase
final watchBlockedAppsUseCaseProvider = Provider<WatchBlockedAppsUseCase>(
  (ref) => getIt<WatchBlockedAppsUseCase>(),
);

/// Provider for BlockAppUseCase
final blockAppUseCaseProvider = Provider<BlockAppUseCase>(
  (ref) => getIt<BlockAppUseCase>(),
);

/// Provider for UnblockAppUseCase
final unblockAppUseCaseProvider = Provider<UnblockAppUseCase>(
  (ref) => getIt<UnblockAppUseCase>(),
);

/// Provider for SetBlockedAppsUseCase
final setBlockedAppsUseCaseProvider = Provider<SetBlockedAppsUseCase>(
  (ref) => getIt<SetBlockedAppsUseCase>(),
);

/// Future provider for getting all installed apps
final allAppsProvider = FutureProvider<List<InstalledApplication>>((ref) {
  final usecase = ref.watch(getAllAppsUseCaseProvider);
  return usecase();
});

/// Future provider for getting user apps
final userAppsProvider = FutureProvider<List<InstalledApplication>>((ref) {
  final usecase = ref.watch(getUserAppsUseCaseProvider);
  return usecase();
});

/// Stream provider for watching blocked apps
final blockedAppsStreamProvider =
    StreamProvider<List<BlockedApp>>((ref) {
  final usecase = ref.watch(watchBlockedAppsUseCaseProvider);
  return usecase();
});

/// Future provider for getting blocked apps
final blockedAppsProvider = FutureProvider<List<BlockedApp>>((ref) {
  final usecase = ref.watch(getBlockedAppsUseCaseProvider);
  return usecase();
});

/// Future provider for blocking an app
final blockAppProvider =
    FutureProvider.family<void, BlockedApp>((ref, app) async {
  final usecase = ref.watch(blockAppUseCaseProvider);
  await usecase(app);
  // Invalidate blocked apps to refresh
  ref.invalidate(blockedAppsStreamProvider);
  ref.invalidate(blockedAppsProvider);
});

/// Future provider for unblocking an app
final unblockAppProvider =
    FutureProvider.family<void, String>((ref, packageName) async {
  final usecase = ref.watch(unblockAppUseCaseProvider);
  await usecase(packageName);
  ref.invalidate(blockedAppsStreamProvider);
  ref.invalidate(blockedAppsProvider);
});

/// Future provider for setting multiple blocked apps
final setBlockedAppsProvider =
    FutureProvider.family<void, List<BlockedApp>>((ref, apps) async {
  final usecase = ref.watch(setBlockedAppsUseCaseProvider);
  await usecase(apps);
  ref.invalidate(blockedAppsStreamProvider);
  ref.invalidate(blockedAppsProvider);
});

