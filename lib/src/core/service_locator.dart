import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Domain
import '../domain/repositories/task_repository.dart';
import '../domain/repositories/app_manager_repository.dart';
import '../domain/repositories/block_manager_repository.dart';
import '../domain/repositories/accessibility_repository.dart';
import '../domain/usecases/task_usecases.dart';
import '../domain/usecases/app_usecases.dart';
import '../domain/usecases/accessibility_usecases.dart';

// Data
import '../data/repositories/task_repository_impl.dart';
import '../data/repositories/app_repository_impl.dart';
import '../data/repositories/accessibility_repository_impl.dart';
import '../data/datasources/task_data_source.dart';
import '../data/datasources/app_data_source.dart';
import '../data/datasources/accessibility_data_source.dart';
import '../data/datasources/implementations/firestore_task_datasource.dart';
import '../data/datasources/implementations/native_app_datasource.dart';
import '../data/datasources/implementations/shared_preferences_datasource.dart';
import '../data/datasources/implementations/method_channel_accessibility_datasource.dart';

final getIt = GetIt.instance;

/// Bootstrap dependency injection
Future<void> setupServiceLocator() async {
  // ============ DATA SOURCES ============

  // Task data sources
  getIt.registerSingleton<RemoteTaskDataSource>(
    FirebaseRemoteTaskDataSource(firestore: FirebaseFirestore.instance),
  );

  getIt.registerSingleton<LocalTaskDataSource>(
    InMemoryLocalTaskDataSource(),
  );

  // App data sources
  getIt.registerSingleton<RemoteAppDataSource>(
    NativeMethodChannelAppDataSource(),
  );

  final blockedAppsDataSource = SharedPreferencesBlockedAppsDataSource();
  // Initialize in background - don't block UI startup
  blockedAppsDataSource.init().ignore();
  getIt.registerSingleton<LocalBlockedAppsDataSource>(blockedAppsDataSource);

  // Accessibility data source
  getIt.registerSingleton<AccessibilityPlatformDataSource>(
    MethodChannelAccessibilityDataSource(),
  );

  // ============ REPOSITORIES ============

  getIt.registerSingleton<TaskRepository>(
    TaskRepositoryImpl(
      remoteDataSource: getIt<RemoteTaskDataSource>(),
      localDataSource: getIt<LocalTaskDataSource>(),
    ),
  );

  getIt.registerSingleton<AppManagerRepository>(
    AppManagerRepositoryImpl(
      remoteDataSource: getIt<RemoteAppDataSource>(),
    ),
  );

  getIt.registerSingleton<BlockManagerRepository>(
    BlockManagerRepositoryImpl(
      localDataSource: getIt<LocalBlockedAppsDataSource>(),
    ),
  );

  getIt.registerSingleton<AccessibilityRepository>(
    AccessibilityRepositoryImpl(
      platformDataSource: getIt<AccessibilityPlatformDataSource>(),
    ),
  );

  // ============ USE CASES ============

  // Task use cases
  getIt.registerSingleton(GetTasksUseCase(getIt<TaskRepository>()));
  getIt.registerSingleton(SaveTaskUseCase(getIt<TaskRepository>()));
  getIt.registerSingleton(DeleteTaskUseCase(getIt<TaskRepository>()));
  getIt.registerSingleton(MarkTaskStatusUseCase(getIt<TaskRepository>()));
  getIt.registerSingleton(GetCompletionStatsUseCase(getIt<TaskRepository>()));

  // App use cases
  getIt.registerSingleton(GetAllAppsUseCase(getIt<AppManagerRepository>()));
  getIt.registerSingleton(GetUserAppsUseCase(getIt<AppManagerRepository>()));
  getIt.registerSingleton(GetBlockedAppsUseCase(getIt<BlockManagerRepository>()));
  getIt.registerSingleton(
    WatchBlockedAppsUseCase(getIt<BlockManagerRepository>()),
  );
  getIt.registerSingleton(BlockAppUseCase(getIt<BlockManagerRepository>()));
  getIt.registerSingleton(UnblockAppUseCase(getIt<BlockManagerRepository>()));
  getIt.registerSingleton(SetBlockedAppsUseCase(getIt<BlockManagerRepository>()));

  // Accessibility use cases
  getIt.registerSingleton(
    CheckAccessibilityUseCase(getIt<AccessibilityRepository>()),
  );
  getIt.registerSingleton(
    RequestAccessibilityUseCase(getIt<AccessibilityRepository>()),
  );
  getIt.registerSingleton(
    CheckOverlayPermissionUseCase(getIt<AccessibilityRepository>()),
  );
  getIt.registerSingleton(
    RequestOverlayPermissionUseCase(getIt<AccessibilityRepository>()),
  );
  getIt.registerSingleton(
    WatchAccessibilityStatusUseCase(getIt<AccessibilityRepository>()),
  );
  getIt.registerSingleton(
    WatchAppOpeningEventsUseCase(getIt<AccessibilityRepository>()),
  );
}

/// Reset DI for testing
void resetServiceLocator() {
  getIt.reset();
}

