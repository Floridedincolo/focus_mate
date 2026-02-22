# 📋 EXPLICAȚII DETALIATE - 38 Fișiere Noi Adăugate

## 🎯 Doar fișierele pe care le-am creat (excludând documentație)

---

## 📁 DOMAIN LAYER (11 Fișiere)

### 1️⃣ lib/src/domain/entities/task.dart
**Rol:** Entitate Task - reprezentare pură a unei sarcini în domeniu (nu e Flutter-dependentă)

**Conține:**
```dart
class Task {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final bool isActive;
  
  Task copyWith(...) // pentru modificări immutable
}
```

**Cine o folosește:**
- task_repository (interface)
- task_mapper.dart (convertire din DTO)
- task_usecases.dart (business logic)
- presentation/providers (state)

**Notă:** E framework-agnostică - ar funcționa și în CLI app sau web

---

### 2️⃣ lib/src/domain/entities/task_status.dart
**Rol:** Entitate TaskStatus - status-ul unui task pe o anumită dată

**Conține:**
```dart
class TaskStatus {
  final String taskId;
  final DateTime date;
  final String status; // 'completed', 'missed', 'upcoming', 'hidden'
  final DateTime? completedAt;
  
  TaskStatus copyWith(...)
}
```

**Cine o folosește:**
- task_repository (getTaskStatus)
- task_mapper (din DTO)
- task_usecases (business logic)

**Notă:** Crítico pentru feature-ul de marcare status pe dată

---

### 3️⃣ lib/src/domain/entities/installed_application.dart
**Rol:** Entitate InstalledApplication - info despre o aplicație instalată

**Conține:**
```dart
class InstalledApplication {
  final String packageName;
  final String appName;
  final bool isSystemApp;
  final List<int>? iconBytes; // icon-ul ca bytes
  
  InstalledApplication copyWith(...)
}
```

**Cine o folosește:**
- app_manager_repository (getApps)
- app_mapper (conversie din DTO)
- app_usecases (business logic)
- presentation/providers (UI afișează aplicații)

**Notă:** Decorează apps cu icon bytes pentru UI

---

### 4️⃣ lib/src/domain/entities/blocked_app.dart
**Rol:** Entitate BlockedApp - o aplicație care e blocată în Focus mode

**Conține:**
```dart
class BlockedApp {
  final String packageName;
  final String appName;
  final DateTime blockedSince;
  
  BlockedApp copyWith(...)
}
```

**Cine o folosește:**
- block_manager_repository (lista blocate)
- app_mapper (conversie)
- app_usecases (block/unblock logic)

**Notă:** Reprezintă starea "blocată" a unui app

---

### 5️⃣ lib/src/domain/repositories/task_repository.dart
**Rol:** CONTRACT - interfață pentru operații cu tasks

**Conține (abstract methods):**
```dart
abstract class TaskRepository {
  Stream<List<Task>> watchTasks();
  Future<void> saveTask(Task task);
  Future<void> deleteTask(String taskId);
  Future<TaskStatus?> getTaskStatus(String taskId, DateTime date);
  Future<void> markTaskStatus(String taskId, DateTime date, String status);
  Future<int> getCompletionStats(String taskId, DateTime date);
}
```

**Cine o implementează:**
- task_repository_impl.dart

**Cine o folosește:**
- task_usecases.dart (business rules)
- data layer (implementations)

**Notă:** Abstracție pură - nu ştie de Firestore, Firebase, etc.

---

### 6️⃣ lib/src/domain/repositories/app_manager_repository.dart
**Rol:** CONTRACT - interfață pentru app management (get apps, icons)

**Conține (abstract methods):**
```dart
abstract class AppManagerRepository {
  Future<List<InstalledApplication>> getAllApps();
  Future<List<InstalledApplication>> getUserApps();
  Future<String?> getAppName(String packageName);
  Future<List<int>?> getAppIcon(String packageName);
}
```

**Cine o implementează:**
- app_repository_impl.dart

**Cine o folosește:**
- app_usecases.dart

**Notă:** Abstrage accesul la native list of apps

---

### 7️⃣ lib/src/domain/repositories/block_manager_repository.dart
**Rol:** CONTRACT - interfață pentru blocarea/deblocarea apps

**Conține (abstract methods):**
```dart
abstract class BlockManagerRepository {
  Stream<List<BlockedApp>> watchBlockedApps();
  Future<void> blockApp(BlockedApp app);
  Future<void> unblockApp(String packageName);
  Future<void> setBlockedApps(List<BlockedApp> apps);
  Future<void> clearBlockedApps();
}
```

**Cine o implementează:**
- app_repository_impl.dart

**Cine o folosește:**
- app_usecases.dart

**Notă:** Interfață pentru persistență și aplicare blocare

---

### 8️⃣ lib/src/domain/repositories/accessibility_repository.dart
**Rol:** CONTRACT - interfață pentru accessibility service status

**Conține (abstract methods):**
```dart
abstract class AccessibilityRepository {
  Future<bool> isAccessibilityEnabled();
  Future<void> requestAccessibility();
  Future<bool> canDrawOverlays();
  Future<void> requestOverlayPermission();
  Stream<bool> watchAccessibilityStatus();
  Stream<String> watchAppOpeningEvents();
}
```

**Cine o implementează:**
- accessibility_repository_impl.dart

**Cine o folosește:**
- accessibility_usecases.dart

**Notă:** Abstrage native permission checks

---

### 9️⃣ lib/src/domain/usecases/task_usecases.dart
**Rol:** USE CASES - clase care incapsulează reguli business pentru tasks

**Conține (5 use cases):**
```dart
class GetTasksUseCase {
  Stream<List<Task>> call() => _repository.watchTasks();
}

class SaveTaskUseCase {
  Future<void> call(Task task) => _repository.saveTask(task);
}

class DeleteTaskUseCase {
  Future<void> call(String taskId) => _repository.deleteTask(taskId);
}

class MarkTaskStatusUseCase {
  Future<void> call(String taskId, DateTime date, String status) 
    => _repository.markTaskStatus(taskId, date, status);
}

class GetCompletionStatsUseCase {
  // Computează statistici
}
```

**Cine o folosește:**
- task_providers.dart (Riverpod)
- service_locator.dart (DI registration)

**Notă:** Fiecare use case = o acțiune business specifică

---

### 🔟 lib/src/domain/usecases/app_usecases.dart
**Rol:** USE CASES - logică business pentru app management

**Conține (7 use cases):**
```dart
class GetAllAppsUseCase { }
class GetUserAppsUseCase { }
class GetBlockedAppsUseCase { }
class WatchBlockedAppsUseCase { }
class BlockAppUseCase { }
class UnblockAppUseCase { }
class SetBlockedAppsUseCase { }
```

**Cine o folosește:**
- app_providers.dart (UI)
- service_locator.dart (DI)

**Notă:** Separă logica app-blocking de UI

---

### 1️⃣1️⃣ lib/src/domain/usecases/accessibility_usecases.dart
**Rol:** USE CASES - logică pentru accessibility service

**Conține (6 use cases):**
```dart
class CheckAccessibilityUseCase { }
class RequestAccessibilityUseCase { }
class CheckOverlayPermissionUseCase { }
class RequestOverlayPermissionUseCase { }
class WatchAccessibilityStatusUseCase { }
class WatchAppOpeningEventsUseCase { }
```

**Cine o folosește:**
- accessibility_providers.dart (UI)
- service_locator.dart (DI)

**Notă:** Abstractizează verificări platform

---

### 1️⃣2️⃣ lib/src/domain/errors/domain_errors.dart
**Rol:** DOMAIN EXCEPTIONS - erori specifice domeniului

**Conține:**
```dart
sealed class DomainException implements Exception {
  final String message;
  final Object? originalException;
}

class TaskException extends DomainException { }
class AppManagerException extends DomainException { }
class AccessibilityException extends DomainException { }
class DataException extends DomainException { }
```

**Cine o folosește:**
- Repositories (throw exceptions)
- Use cases (may catch/rethrow)
- Providers (error handling)

**Notă:** Tipuri de erori specific domeniului (nu generic Exception)

---

## 📁 DATA LAYER (13 Fișiere)

### 1️⃣ lib/src/data/dtos/task_dto.dart
**Rol:** DTO - reprezentare a datelor cum vin din Firestore

**Conține:**
```dart
class TaskDTO {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  
  // Conversii Firestore
  factory TaskDTO.fromFirestore(Map<String, dynamic> data) { }
  Map<String, dynamic> toFirestore() { }
}

class TaskStatusDTO {
  final String taskId;
  final DateTime date;
  final String status;
  
  factory TaskStatusDTO.fromFirestore(...) { }
  Map<String, dynamic> toFirestore() { }
}
```

**Cine o folosește:**
- firestore_task_datasource.dart (fetch from Firestore)
- task_mapper.dart (convert to Task entity)

**Notă:** Forma în care Firestore îi returnează datele

---

### 2️⃣ lib/src/data/dtos/app_dto.dart
**Rol:** DTO - reprezentare apps din native layer + SharedPreferences

**Conține:**
```dart
class InstalledApplicationDTO {
  final String packageName;
  final String appName;
  final bool isSystemApp;
  final String? iconBase64; // Codificat base64
  
  factory InstalledApplicationDTO.fromMap(...) { }
}

class BlockedAppDTO {
  final String packageName;
  final String appName;
  
  factory BlockedAppDTO.fromJson(String json) { }
  String toJson() { }
}
```

**Cine o folosește:**
- native_app_datasource.dart (din Kotlin)
- shared_preferences_datasource.dart (local storage)
- app_mapper.dart (convert to entities)

**Notă:** Format extern vs format intern (domain entities)

---

### 3️⃣ lib/src/data/mappers/task_mapper.dart
**Rol:** MAPPER - convertire TaskDTO ↔ Task entity

**Conține:**
```dart
class TaskMapper {
  static Task toDomain(TaskDTO dto) {
    return Task(
      id: dto.id,
      title: dto.title,
      // ... map all fields
    );
  }
  
  static TaskDTO toDTO(Task entity) {
    return TaskDTO(
      // ... reverse mapping
    );
  }
  
  static List<Task> toDomainList(List<TaskDTO> dtos) { }
}

class TaskStatusMapper {
  // Similar: TaskStatusDTO ↔ TaskStatus
}
```

**Cine o folosește:**
- firestore_task_datasource.dart (after fetch)
- task_repository_impl.dart (returns domain entities)

**Notă:** Transformă date externe în domeniu

---

### 4️⃣ lib/src/data/mappers/app_mapper.dart
**Rol:** MAPPER - convertire app DTOs ↔ entities

**Conține:**
```dart
class InstalledApplicationMapper {
  static InstalledApplication toDomain(InstalledApplicationDTO dto) {
    return InstalledApplication(
      packageName: dto.packageName,
      appName: dto.appName,
      iconBytes: _decodeBase64(dto.iconBase64),
    );
  }
  // ... reverse
}

class BlockedAppMapper {
  static BlockedApp toDomain(BlockedAppDTO dto) { }
}
```

**Cine o folosește:**
- native_app_datasource.dart + shared_preferences_datasource.dart
- app_repository_impl.dart

**Notă:** Decodare icon base64 și structurare date

---

### 5️⃣ lib/src/data/datasources/task_data_source.dart
**Rol:** DATA SOURCE INTERFACE - contract pentru task persistence

**Conține (abstract interfaces):**
```dart
abstract class RemoteTaskDataSource {
  Stream<List<TaskDTO>> watchTasks();
  Future<void> saveTask(TaskDTO task);
  Future<void> deleteTask(String taskId);
  Future<TaskDTO?> getTaskStatus(String taskId, DateTime date);
}

abstract class LocalTaskDataSource {
  Stream<List<TaskDTO>> watchTasks();
  Future<void> cacheTask(TaskDTO task);
}
```

**Cine o implementează:**
- firestore_task_datasource.dart (remote)
- (in-memory local cache)

**Cine o folosește:**
- task_repository_impl.dart

**Notă:** Abstrage cum sunt stocate tasks (Firestore vs. local cache)

---

### 6️⃣ lib/src/data/datasources/app_data_source.dart
**Rol:** DATA SOURCE INTERFACE - contract pentru app data

**Conține (abstract interfaces):**
```dart
abstract class RemoteAppDataSource {
  Future<List<InstalledApplicationDTO>> getInstalledApps();
  Future<String?> getAppName(String packageName);
  Future<InstalledApplicationDTO?> getAppIcon(String packageName);
}

abstract class LocalBlockedAppsDataSource {
  Future<List<BlockedAppDTO>> getBlockedApps();
  Future<void> setBlockedApps(List<BlockedAppDTO> apps);
}
```

**Cine o implementează:**
- native_app_datasource.dart (remote - Kotlin MethodChannel)
- shared_preferences_datasource.dart (local)

**Cine o folosește:**
- app_repository_impl.dart

**Notă:** Separă native access de local persistence

---

### 7️⃣ lib/src/data/datasources/accessibility_data_source.dart
**Rol:** DATA SOURCE INTERFACE - contract pentru accessibility service

**Conține (abstract interface):**
```dart
abstract class AccessibilityPlatformDataSource {
  Future<bool> isAccessibilityEnabled();
  Future<void> requestAccessibility();
  Future<bool> canDrawOverlays();
  Stream<bool> watchAccessibilityStatus();
  Stream<String> watchAppOpeningEvents();
}
```

**Cine o implementează:**
- method_channel_accessibility_datasource.dart

**Cine o folosește:**
- accessibility_repository_impl.dart

**Notă:** Pure abstraction de native layer

---

### 8️⃣ lib/src/data/datasources/implementations/firestore_task_datasource.dart
**Rol:** IMPLEMENTATION - Firestore-based task data source

**Conține:**
```dart
class FirebaseRemoteTaskDataSource implements RemoteTaskDataSource {
  final FirebaseFirestore _firestore;
  
  @override
  Stream<List<TaskDTO>> watchTasks() {
    return _firestore
      .collection('tasks')
      .snapshots()
      .map((snapshot) => 
        snapshot.docs
          .map((doc) => TaskDTO.fromFirestore(doc.data()))
          .toList()
      );
  }
  
  @override
  Future<void> saveTask(TaskDTO task) {
    return _firestore
      .collection('tasks')
      .doc(task.id)
      .set(task.toFirestore());
  }
  
  // ... other methods
}

class InMemoryLocalTaskDataSource implements LocalTaskDataSource {
  // Simple in-memory cache
}
```

**Cine o folosește:**
- task_repository_impl.dart
- service_locator.dart (registered here)

**Notă:** Real Firestore persistence + in-memory local cache

---

### 9️⃣ lib/src/data/datasources/implementations/native_app_datasource.dart
**Rol:** IMPLEMENTATION - native MethodChannel apps listing

**Conține:**
```dart
class NativeMethodChannelAppDataSource implements RemoteAppDataSource {
  static const _channel = MethodChannel('focus_mate/app_manager');
  
  @override
  Future<List<InstalledApplicationDTO>> getInstalledApps() async {
    final List<dynamic> apps = await _channel.invokeMethod('getInstalledApps');
    return apps
      .map((app) => InstalledApplicationDTO.fromMap(app as Map))
      .toList();
  }
  
  @override
  Future<InstalledApplicationDTO?> getAppIcon(String packageName) async {
    final icon = await _channel.invokeMethod('getAppIcon', {'package': packageName});
    return icon != null ? InstalledApplicationDTO.fromMap(icon) : null;
  }
}
```

**Cine o folosește:**
- app_repository_impl.dart
- service_locator.dart

**Notă:** Vorbește cu Kotlin via MethodChannel pentru lista apps

---

### 🔟 lib/src/data/datasources/implementations/shared_preferences_datasource.dart
**Rol:** IMPLEMENTATION - local persistence of blocked apps list

**Conține:**
```dart
class SharedPreferencesBlockedAppsDataSource implements LocalBlockedAppsDataSource {
  late SharedPreferences _prefs;
  
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  @override
  Future<List<BlockedAppDTO>> getBlockedApps() async {
    final json = _prefs.getStringList('blocked_apps') ?? [];
    return json.map((s) => BlockedAppDTO.fromJson(s)).toList();
  }
  
  @override
  Future<void> setBlockedApps(List<BlockedAppDTO> apps) async {
    final json = apps.map((app) => app.toJson()).toList();
    await _prefs.setStringList('blocked_apps', json);
  }
}
```

**Cine o folosește:**
- app_repository_impl.dart
- service_locator.dart (initialized async background)

**Notă:** Persistă lista blocate in SharedPreferences - init() în background

---

### 1️⃣1️⃣ lib/src/data/datasources/implementations/method_channel_accessibility_datasource.dart
**Rol:** IMPLEMENTATION - native accessibility MethodChannel

**Conține:**
```dart
class MethodChannelAccessibilityDataSource implements AccessibilityPlatformDataSource {
  static const _channel = MethodChannel('focus_mate/accessibility');
  
  @override
  Future<bool> isAccessibilityEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool?>('checkAccessibility')
        .timeout(Duration(seconds: 2), onTimeout: () => false);
      return result ?? false;
    } catch (e) {
      print('Error: $e');
      return false; // Safe default
    }
  }
  
  @override
  Stream<bool> watchAccessibilityStatus() async* {
    yield await isAccessibilityEnabled();
    
    while (true) {
      await Future.delayed(Duration(seconds: 5));
      try {
        yield await isAccessibilityEnabled();
      } catch (e) {
        print('Polling error: $e');
      }
    }
  }
  
  // ... other methods with similar timeout + error handling
}
```

**Cine o folosește:**
- accessibility_repository_impl.dart
- service_locator.dart

**Notă:** **IMPORTANT:** Toate MethodChannel calls au 2s timeout + safe defaults pentru a nu bloca app!

---

### 1️⃣2️⃣ lib/src/data/repositories/task_repository_impl.dart
**Rol:** CONCRETE REPOSITORY - implementează TaskRepository interface

**Conține:**
```dart
class TaskRepositoryImpl implements TaskRepository {
  final RemoteTaskDataSource remoteDataSource;
  final LocalTaskDataSource localDataSource;
  
  @override
  Stream<List<Task>> watchTasks() {
    return remoteDataSource
      .watchTasks()
      .map(TaskMapper.toDomainList); // Convert DTO → Task
  }
  
  @override
  Future<void> saveTask(Task task) {
    final dto = TaskMapper.toDTO(task); // Task → DTO
    return remoteDataSource.saveTask(dto);
  }
  
  // ... other methods
}
```

**Cine o folosește:**
- task_usecases.dart (inject in constructor)
- service_locator.dart (registered)

**Notă:** Coordonează remote + local, face mapare DTO → Entity

---

### 1️⃣3️⃣ lib/src/data/repositories/app_repository_impl.dart
**Rol:** CONCRETE REPOSITORY - implementează app repositories

**Conține:**
```dart
class AppManagerRepositoryImpl implements AppManagerRepository {
  final RemoteAppDataSource remoteDataSource;
  
  @override
  Future<List<InstalledApplication>> getUserApps() async {
    final dtos = await remoteDataSource.getInstalledApps();
    return dtos
      .where((dto) => !dto.isSystemApp) // Filter system apps
      .map(AppMapper.toDomain)
      .toList();
  }
  
  @override
  Future<List<int>?> getAppIcon(String packageName) async {
    final dto = await remoteDataSource.getAppIcon(packageName);
    if (dto?.iconBase64 == null) return null;
    return base64.decode(dto!.iconBase64!); // Decode base64 → bytes
  }
}

class BlockManagerRepositoryImpl implements BlockManagerRepository {
  final LocalBlockedAppsDataSource localDataSource;
  
  @override
  Future<void> blockApp(BlockedApp app) {
    final dto = AppMapper.toDTO(app);
    return localDataSource.setBlockedApps([...existing, dto]);
  }
}
```

**Cine o folosește:**
- app_usecases.dart
- service_locator.dart

**Notă:** Coordonează native + local, filterează system apps, decodează icons

---

### 1️⃣4️⃣ lib/src/data/repositories/accessibility_repository_impl.dart
**Rol:** CONCRETE REPOSITORY - implementează AccessibilityRepository interface

**Conține:**
```dart
class AccessibilityRepositoryImpl implements AccessibilityRepository {
  final AccessibilityPlatformDataSource platformDataSource;
  
  @override
  Future<bool> isAccessibilityEnabled() {
    return platformDataSource.isAccessibilityEnabled();
  }
  
  @override
  Stream<bool> watchAccessibilityStatus() {
    return platformDataSource.watchAccessibilityStatus();
  }
  
  // ... other methods delegate to platform data source
}
```

**Cine o folosește:**
- accessibility_usecases.dart
- service_locator.dart

**Notă:** Thin wrapper delegating to platform data source (care are timeouts)

---

## 📁 PRESENTATION LAYER (3 Fișiere)

### 1️⃣ lib/src/presentation/providers/task_providers.dart
**Rol:** RIVERPOD PROVIDERS - state management for tasks

**Conține (8 providers):**
```dart
// Use case providers
final getTasksUseCaseProvider = Provider<GetTasksUseCase>(
  (ref) => getIt<GetTasksUseCase>(),
);

// Stream provider: watch all tasks
final tasksStreamProvider = StreamProvider<List<Task>>((ref) {
  final usecase = ref.watch(getTasksUseCaseProvider);
  return usecase();
});

// Future provider: save task + invalidate stream
final saveTaskProvider = FutureProvider.family<void, Task>((ref, task) async {
  final usecase = ref.watch(saveTaskUseCaseProvider);
  await usecase(task);
  ref.invalidate(tasksStreamProvider); // Refresh UI
});

// Future provider: delete task
final deleteTaskProvider = FutureProvider.family<void, String>((ref, taskId) async {
  final usecase = ref.watch(deleteTaskUseCaseProvider);
  await usecase(taskId);
  ref.invalidate(tasksStreamProvider);
});

// ... more providers for mark status, completion stats, etc.
```

**Cine o folosește:**
- presentation/pages (UI widgets watch these)
- service_locator.dart (registered providers)

**Notă:** Bridge between UI (ConsumerWidget) și domain use-cases; automatic caching + rebuilds

---

### 2️⃣ lib/src/presentation/providers/app_providers.dart
**Rol:** RIVERPOD PROVIDERS - state management for apps

**Conține (10+ providers):**
```dart
// Use case providers
final getAllAppsUseCaseProvider = Provider<GetAllAppsUseCase>(
  (ref) => getIt<GetAllAppsUseCase>(),
);

// Stream: watch all installed apps
final allAppsProvider = FutureProvider<List<InstalledApplication>>((ref) {
  return ref.watch(getAllAppsUseCaseProvider)();
});

// Stream: watch blocked apps
final blockedAppsStreamProvider = StreamProvider<List<BlockedApp>>((ref) {
  final usecase = ref.watch(watchBlockedAppsUseCaseProvider);
  return usecase();
});

// Future: block app + invalidate stream
final blockAppProvider = FutureProvider.family<void, BlockedApp>((ref, app) async {
  final usecase = ref.watch(blockAppUseCaseProvider);
  await usecase(app);
  ref.invalidate(blockedAppsStreamProvider);
});

// Computed: filtered apps (not blocked)
final availableAppsProvider = Provider<List<InstalledApplication>>((ref) {
  final allApps = ref.watch(allAppsProvider);
  final blockedApps = ref.watch(blockedAppsStreamProvider);
  
  return allApps.when(
    data: (apps) => blockedApps.when(
      data: (blocked) => apps.where((a) =>
        !blocked.any((b) => b.packageName == a.packageName)
      ).toList(),
      loading: () => [],
      error: (_, __) => apps,
    ),
    loading: () => [],
    error: (_, __) => [],
  );
});

// ... more providers
```

**Cine o folosește:**
- FocusPage (show blocked apps list, block/unblock)
- service_locator.dart

**Notă:** Computed providers sunt derivate din alte providers (smart caching)

---

### 3️⃣ lib/src/presentation/providers/accessibility_providers.dart
**Rol:** RIVERPOD PROVIDERS - state management for accessibility

**Conține (8 providers cu error handling):**
```dart
// Use case providers
final checkAccessibilityUseCaseProvider = Provider<CheckAccessibilityUseCase>(
  (ref) => getIt<CheckAccessibilityUseCase>(),
);

// Future provider with try-catch
final checkAccessibilityProvider = FutureProvider<bool>((ref) async {
  try {
    final usecase = ref.watch(checkAccessibilityUseCaseProvider);
    return await usecase();
  } catch (e) {
    print('Error checking accessibility: $e');
    return false; // Safe default - never crash UI
  }
});

// Stream provider with error handling
final accessibilityStatusStreamProvider = StreamProvider<bool>((ref) async* {
  try {
    final usecase = ref.watch(watchAccessibilityStatusUseCaseProvider);
    yield* usecase();
  } catch (e) {
    print('Error watching accessibility: $e');
    yield false; // Safe default
  }
});

// ... more providers with similar error handling
```

**Cine o folosește:**
- FocusPage (check if accessibility enabled, show warnings)
- service_locator.dart

**Notă:** **IMPORTANT:** Toate providers au try-catch + safe defaults pentru a nu bloca/crasha UI

---

## 📁 CORE LAYER (1 Fișier)

### 1️⃣ lib/src/core/service_locator.dart
**Rol:** DEPENDENCY INJECTION - setup și wiring al tuturor dependențelor

**Conține:**
```dart
final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // ============ REGISTER DATA SOURCES ============
  
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
  blockedAppsDataSource.init().ignore(); // Async, non-blocking init
  getIt.registerSingleton<LocalBlockedAppsDataSource>(blockedAppsDataSource);
  
  // Accessibility data source
  getIt.registerSingleton<AccessibilityPlatformDataSource>(
    MethodChannelAccessibilityDataSource(),
  );
  
  // ============ REGISTER REPOSITORIES ============
  
  getIt.registerSingleton<TaskRepository>(
    TaskRepositoryImpl(
      remoteDataSource: getIt<RemoteTaskDataSource>(),
      localDataSource: getIt<LocalTaskDataSource>(),
    ),
  );
  
  getIt.registerSingleton<AppManagerRepository>(
    AppManagerRepositoryImpl(remoteDataSource: getIt<RemoteAppDataSource>()),
  );
  
  getIt.registerSingleton<BlockManagerRepository>(
    BlockManagerRepositoryImpl(localDataSource: getIt<LocalBlockedAppsDataSource>()),
  );
  
  getIt.registerSingleton<AccessibilityRepository>(
    AccessibilityRepositoryImpl(
      platformDataSource: getIt<AccessibilityPlatformDataSource>(),
    ),
  );
  
  // ============ REGISTER USE CASES ============
  
  getIt.registerSingleton(GetTasksUseCase(getIt<TaskRepository>()));
  getIt.registerSingleton(SaveTaskUseCase(getIt<TaskRepository>()));
  getIt.registerSingleton(DeleteTaskUseCase(getIt<TaskRepository>()));
  getIt.registerSingleton(MarkTaskStatusUseCase(getIt<TaskRepository>()));
  getIt.registerSingleton(GetCompletionStatsUseCase(getIt<TaskRepository>()));
  
  getIt.registerSingleton(GetAllAppsUseCase(getIt<AppManagerRepository>()));
  getIt.registerSingleton(GetUserAppsUseCase(getIt<AppManagerRepository>()));
  getIt.registerSingleton(GetBlockedAppsUseCase(getIt<BlockManagerRepository>()));
  getIt.registerSingleton(WatchBlockedAppsUseCase(getIt<BlockManagerRepository>()));
  getIt.registerSingleton(BlockAppUseCase(getIt<BlockManagerRepository>()));
  getIt.registerSingleton(UnblockAppUseCase(getIt<BlockManagerRepository>()));
  getIt.registerSingleton(SetBlockedAppsUseCase(getIt<BlockManagerRepository>()));
  
  getIt.registerSingleton(CheckAccessibilityUseCase(getIt<AccessibilityRepository>()));
  getIt.registerSingleton(RequestAccessibilityUseCase(getIt<AccessibilityRepository>()));
  getIt.registerSingleton(CheckOverlayPermissionUseCase(getIt<AccessibilityRepository>()));
  getIt.registerSingleton(RequestOverlayPermissionUseCase(getIt<AccessibilityRepository>()));
  getIt.registerSingleton(WatchAccessibilityStatusUseCase(getIt<AccessibilityRepository>()));
  getIt.registerSingleton(WatchAppOpeningEventsUseCase(getIt<AccessibilityRepository>()));
}
```

**Cine o apelează:**
- lib/main.dart `await setupServiceLocator()` la startup

**Cine o folosește:**
- Providers (to get use cases via `getIt<UseCase>()`)
- Service_locator provides access globally via `getIt` singleton

**Notă:** **CRUCIAL FILE** - Single point to change implementations! Wires everything. SharedPreferences init is async non-blocking.

---

## 📊 SUMMARY - 38 Fișiere Noi

| Layer | Folder | Fișiere | Descriere |
|-------|--------|---------|-----------|
| **Domain** | entities/ | 4 | Task, TaskStatus, InstalledApplication, BlockedApp |
| **Domain** | repositories/ | 4 | TaskRepository, AppManagerRepository, BlockManagerRepository, AccessibilityRepository |
| **Domain** | usecases/ | 3 | task_usecases (5 UC), app_usecases (7 UC), accessibility_usecases (6 UC) |
| **Domain** | errors/ | 1 | domain_errors.dart |
| **Data** | dtos/ | 2 | task_dto.dart, app_dto.dart |
| **Data** | mappers/ | 2 | task_mapper.dart, app_mapper.dart |
| **Data** | datasources/ | 3 | task_data_source, app_data_source, accessibility_data_source |
| **Data** | datasources/impl/ | 4 | firestore, native, shared_prefs, method_channel |
| **Data** | repositories/ | 3 | task_repository_impl, app_repository_impl, accessibility_repository_impl |
| **Presentation** | providers/ | 3 | task_providers, app_providers, accessibility_providers |
| **Core** | core/ | 1 | service_locator.dart |
| **TOTAL** | | **38** | |

---

## 🔄 DATA FLOW - Cum Circulă Datele

```
UI (Widget în presentation/pages/)
  ↓ watches/reads
Riverpod Providers (presentation/providers/)
  ↓ uses
Use Cases (domain/usecases/)
  ↓ calls
Repositories (domain/repositories/ interface)
  ↓ implemented by
Repository Impl (data/repositories/)
  ↓ uses
Data Sources (data/datasources/)
  ↓ accesses
Firestore / SharedPreferences / MethodChannel
```

---

## ✅ CUM SĂ FOLOSEȘTI ARHITECTURA

### Adaugă Task Nou:
1. UI (button click) → calls `ref.read(saveTaskProvider(newTask))`
2. Provider → uses SaveTaskUseCase
3. Use case → calls taskRepository.saveTask()
4. Repository impl → converts Task to TaskDTO
5. Data source → saves to Firestore
6. Provider invalidates → UI rebuilds with new task

### Obții lista task-urilor:
1. UI → `ref.watch(tasksStreamProvider)`
2. Provider → GetTasksUseCase
3. Use case → repository.watchTasks()
4. Repository → remoteDataSource.watchTasks()
5. Data source → Firestore stream
6. Mapped → TaskDTO → Task entity
7. UI gets List<Task> și rebuilds automat

---

**Asta sunt toate 38 fișierele noi pe care le-am adăugat!** 🎉

