import 'package:get_it/get_it.dart';
import 'package:cloud_functions/cloud_functions.dart';

// Domain
import '../domain/repositories/task_repository.dart';
import '../domain/repositories/app_manager_repository.dart';
import '../domain/repositories/block_manager_repository.dart';
import '../domain/repositories/accessibility_repository.dart';
import '../domain/repositories/schedule_import_repository.dart';
import '../domain/repositories/friend_repository.dart';
import '../domain/repositories/meeting_suggestion_repository.dart';
import '../domain/usecases/task_usecases.dart';
import '../domain/usecases/app_usecases.dart';
import '../domain/usecases/accessibility_usecases.dart';
import '../domain/usecases/extract_schedule_from_image_use_case.dart';
import '../domain/usecases/generate_weekly_tasks_use_case.dart';
import '../domain/usecases/friend_usecases.dart';
import '../domain/usecases/suggest_meeting_algorithmic_use_case.dart';
import '../domain/usecases/suggest_meeting_ai_use_case.dart';

// Data
import '../data/repositories/task_repository_impl.dart';
import '../data/repositories/app_repository_impl.dart';
import '../data/repositories/accessibility_repository_impl.dart';
import '../data/repositories/schedule_import_repository_impl.dart';
import '../data/repositories/friend_repository_impl.dart';
import '../data/repositories/meeting_suggestion_repository_impl.dart';
import '../data/datasources/task_data_source.dart';
import '../data/datasources/app_data_source.dart';
import '../data/datasources/accessibility_data_source.dart';
import '../data/datasources/schedule_import_datasource.dart';
import '../data/datasources/friend_data_source.dart';
import '../data/datasources/meeting_suggestion_data_source.dart';
import '../data/datasources/implementations/cloud_function_schedule_import_datasource.dart';
import '../data/datasources/implementations/firestore_task_datasource.dart';
import '../data/datasources/implementations/native_app_datasource.dart';
import '../data/datasources/implementations/shared_preferences_datasource.dart';
import '../data/datasources/implementations/method_channel_accessibility_datasource.dart';
import '../data/datasources/implementations/firestore_friend_datasource.dart';
import '../data/datasources/implementations/gemini_meeting_suggestion_datasource.dart';

final getIt = GetIt.instance;

/// Bootstrap dependency injection
Future<void> setupServiceLocator() async {
  // ============ DATA SOURCES ============

  // Task data sources
  getIt.registerSingleton<RemoteTaskDataSource>(
    FirebaseRemoteTaskDataSource(),
  );

  getIt.registerSingleton<LocalTaskDataSource>(
    InMemoryLocalTaskDataSource(),
  );

  // App data sources
  getIt.registerSingleton<RemoteAppDataSource>(
    NativeMethodChannelAppDataSource(),
  );

  final blockedAppsDataSource = SharedPreferencesBlockedAppsDataSource();
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
  getIt.registerSingleton(ArchiveTaskUseCase(getIt<TaskRepository>()));
  getIt.registerSingleton(GetCompletionStatusUseCase(getIt<TaskRepository>()));
  getIt.registerSingleton(MarkTaskStatusUseCase(getIt<TaskRepository>()));
  getIt.registerSingleton(ClearCompletionUseCase(getIt<TaskRepository>()));

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

  // ============ SCHEDULE IMPORT ============

  // Data source — calls the `extractSchedule` Cloud Function which handles
  // authentication, rate limiting, image validation, and prompt management
  // server-side. See functions/src/index.ts.
  getIt.registerSingleton<ScheduleImportDataSource>(
    CloudFunctionScheduleImportDataSource(
      FirebaseFunctions.instanceFor(region: 'europe-west1'),
    ),
  );

  getIt.registerSingleton<ScheduleImportRepository>(
    ScheduleImportRepositoryImpl(getIt<ScheduleImportDataSource>()),
  );

  // Use cases
  getIt.registerSingleton(
    ExtractScheduleFromImageUseCase(getIt<ScheduleImportRepository>()),
  );
  // GenerateWeeklyTasksUseCase is a stateless value object — registered as
  // factory so each call gets a fresh instance.
  getIt.registerFactory<GenerateWeeklyTasksUseCase>(
    GenerateWeeklyTasksUseCase.new,
  );

  // ============ FRIENDS & MEETING SUGGESTIONS ============

  // Data sources
  getIt.registerSingleton<FriendDataSource>(
    FirestoreFriendDataSource(),
  );

  getIt.registerSingleton<MeetingSuggestionDataSource>(
    GeminiMeetingSuggestionDataSource(),
  );

  // Repositories
  getIt.registerSingleton<FriendRepository>(
    FriendRepositoryImpl(getIt<FriendDataSource>()),
  );

  getIt.registerSingleton<MeetingSuggestionRepository>(
    MeetingSuggestionRepositoryImpl(getIt<MeetingSuggestionDataSource>()),
  );

  // Friend use cases
  getIt.registerSingleton(
    SendFriendRequestUseCase(getIt<FriendRepository>()),
  );
  getIt.registerSingleton(
    AcceptFriendRequestUseCase(getIt<FriendRepository>()),
  );
  getIt.registerSingleton(
    DeclineFriendRequestUseCase(getIt<FriendRepository>()),
  );
  getIt.registerSingleton(
    GetFriendsListUseCase(getIt<FriendRepository>()),
  );
  getIt.registerSingleton(
    WatchFriendsUseCase(getIt<FriendRepository>()),
  );
  getIt.registerSingleton(
    WatchIncomingRequestsUseCase(getIt<FriendRepository>()),
  );

  // Meeting suggestion use cases
  getIt.registerSingleton(
    const SuggestMeetingAlgorithmicUseCase(),
  );
  getIt.registerSingleton(
    SuggestMeetingAiUseCase(getIt<MeetingSuggestionRepository>()),
  );
}

/// Reset DI for testing
void resetServiceLocator() {
  getIt.reset();
}

