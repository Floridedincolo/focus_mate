# 🔗 RELATIONSHIP DIAGRAM - Cum Se Conectează Fișierele

## Fluxul General

```
┌─────────────────────────────────────────────────────────┐
│                    UI (lib/pages/)                       │
│              (Home, Focus, Stats, Profile)               │
└──────────────────────┬──────────────────────────────────┘
                       │
                       │ watches/reads
                       ↓
┌─────────────────────────────────────────────────────────┐
│           RIVERPOD PROVIDERS                             │
│  ┌──────────────────────────────────────────────────┐    │
│  │ • task_providers.dart (8 providers)              │    │
│  │ • app_providers.dart (10 providers)              │    │
│  │ • accessibility_providers.dart (8 providers)     │    │
│  └──────────────────────────────────────────────────┘    │
└──────────────────────┬──────────────────────────────────┘
                       │
                       │ uses/injects
                       ↓
┌─────────────────────────────────────────────────────────┐
│                  USE CASES                               │
│  ┌──────────────────────────────────────────────────┐    │
│  │ • task_usecases.dart (5 use cases)               │    │
│  │ • app_usecases.dart (7 use cases)                │    │
│  │ • accessibility_usecases.dart (6 use cases)      │    │
│  └──────────────────────────────────────────────────┘    │
└──────────────────────┬──────────────────────────────────┘
                       │
                       │ calls
                       ↓
┌─────────────────────────────────────────────────────────┐
│              REPOSITORY INTERFACES                        │
│  ┌──────────────────────────────────────────────────┐    │
│  │ • task_repository.dart                           │    │
│  │ • app_manager_repository.dart                    │    │
│  │ • block_manager_repository.dart                  │    │
│  │ • accessibility_repository.dart                  │    │
│  └──────────────────────────────────────────────────┘    │
└──────────────────────┬──────────────────────────────────┘
                       │
                       │ implemented by
                       ↓
┌─────────────────────────────────────────────────────────┐
│            REPOSITORY IMPLEMENTATIONS                     │
│  ┌──────────────────────────────────────────────────┐    │
│  │ • task_repository_impl.dart                      │    │
│  │ • app_repository_impl.dart                       │    │
│  │ • accessibility_repository_impl.dart             │    │
│  └──────────────────────────────────────────────────┘    │
└──────────────────────┬──────────────────────────────────┘
                       │
                       │ uses
                       ↓
┌─────────────────────────────────────────────────────────┐
│             DATA SOURCES (interfaces)                     │
│  ┌──────────────────────────────────────────────────┐    │
│  │ • task_data_source.dart                          │    │
│  │ • app_data_source.dart                           │    │
│  │ • accessibility_data_source.dart                 │    │
│  └──────────────────────────────────────────────────┘    │
└──────────────────────┬──────────────────────────────────┘
                       │
                       │ implemented by
                       ↓
┌─────────────────────────────────────────────────────────┐
│           DATA SOURCES (implementations)                  │
│  ┌──────────────────────────────────────────────────┐    │
│  │ • firestore_task_datasource.dart                 │    │
│  │ • native_app_datasource.dart                     │    │
│  │ • shared_preferences_datasource.dart             │    │
│  │ • method_channel_accessibility_datasource.dart   │    │
│  └──────────────────────────────────────────────────┘    │
└──────────────────────┬──────────────────────────────────┘
                       │
                       │ accesses
                       ↓
┌─────────────────────────────────────────────────────────┐
│         EXTERNAL RESOURCES                               │
│  ┌──────────────────────────────────────────────────┐    │
│  │ • Firestore (remote)                             │    │
│  │ • SharedPreferences (local)                      │    │
│  │ • MethodChannel → Kotlin (native)                │    │
│  │ • In-memory cache                                │    │
│  └──────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

---

## Detaliat pe Subsistem

### 1️⃣ TASK MANAGEMENT FLOW

```
HOME PAGE (shows calendar + task list)
    ↓ ref.watch(tasksStreamProvider)
TASK PROVIDERS
    ├─ tasksStreamProvider
    │  └─ GetTasksUseCase
    │     └─ TaskRepository (interface)
    │        └─ TaskRepositoryImpl
    │           ├─ RemoteTaskDataSource
    │           │  └─ FirebaseRemoteTaskDataSource
    │           │     └─ Firestore (watches collection)
    │           └─ LocalTaskDataSource
    │              └─ InMemoryLocalTaskDataSource (cache)
    │
    ├─ saveTaskProvider (for creating/editing)
    │  └─ SaveTaskUseCase
    │     └─ TaskRepository.saveTask()
    │        └─ TaskRepositoryImpl
    │           └─ RemoteTaskDataSource.saveTask()
    │              └─ Firestore.doc().set()
    │
    └─ deleteTaskProvider
       └─ DeleteTaskUseCase
          └─ TaskRepository.deleteTask()
             └─ Firestore.doc().delete()

DATA FLOW:
  Task (entity) ←→ TaskDTO (DTO)
  [Mapped by TaskMapper]

ENTITIES INVOLVED:
  • Task (lib/src/domain/entities/task.dart)
  • TaskStatus (lib/src/domain/entities/task_status.dart)
  • TaskDTO (lib/src/data/dtos/task_dto.dart)
  • TaskMapper (lib/src/data/mappers/task_mapper.dart)
```

---

### 2️⃣ APP BLOCKING FLOW

```
FOCUS PAGE (shows blocked apps list)
    ↓ ref.watch(blockedAppsStreamProvider)
APP PROVIDERS
    ├─ blockedAppsStreamProvider
    │  └─ WatchBlockedAppsUseCase
    │     └─ BlockManagerRepository (interface)
    │        └─ BlockManagerRepositoryImpl
    │           └─ LocalBlockedAppsDataSource
    │              └─ SharedPreferencesBlockedAppsDataSource
    │                 └─ SharedPreferences (key: 'blocked_apps')
    │
    ├─ blockAppProvider (for blocking an app)
    │  └─ BlockAppUseCase
    │     └─ BlockManagerRepository.blockApp()
    │        └─ BlockManagerRepositoryImpl
    │           └─ LocalBlockedAppsDataSource.setBlockedApps()
    │              └─ SharedPreferences.setStringList()
    │
    ├─ allAppsProvider (list of installed apps)
    │  └─ GetAllAppsUseCase
    │     └─ AppManagerRepository (interface)
    │        └─ AppManagerRepositoryImpl
    │           └─ RemoteAppDataSource (native)
    │              └─ NativeMethodChannelAppDataSource
    │                 └─ MethodChannel → Kotlin getInstalledApps()
    │
    └─ availableAppsProvider (computed: all apps - blocked apps)
       └─ Combines allAppsProvider + blockedAppsStreamProvider

DATA FLOW:
  BlockedApp (entity) ←→ BlockedAppDTO (DTO)
  InstalledApplication (entity) ←→ InstalledApplicationDTO (DTO)
  [Mapped by AppMapper]

ENTITIES INVOLVED:
  • BlockedApp (lib/src/domain/entities/blocked_app.dart)
  • InstalledApplication (lib/src/domain/entities/installed_application.dart)
  • AppDTO (lib/src/data/dtos/app_dto.dart)
  • AppMapper (lib/src/data/mappers/app_mapper.dart)
```

---

### 3️⃣ ACCESSIBILITY FLOW

```
FOCUS PAGE (shows accessibility status + request button)
    ↓ ref.watch(checkAccessibilityProvider)
ACCESSIBILITY PROVIDERS
    ├─ checkAccessibilityProvider
    │  └─ CheckAccessibilityUseCase
    │     └─ AccessibilityRepository (interface)
    │        └─ AccessibilityRepositoryImpl
    │           └─ AccessibilityPlatformDataSource
    │              └─ MethodChannelAccessibilityDataSource
    │                 └─ MethodChannel → Kotlin checkAccessibility()
    │                    [WITH 2s TIMEOUT + ERROR HANDLING]
    │
    ├─ requestAccessibilityProvider
    │  └─ RequestAccessibilityUseCase
    │     └─ AccessibilityRepository.requestAccessibility()
    │        └─ MethodChannelAccessibilityDataSource
    │           └─ MethodChannel → Kotlin promptAccessibility()
    │
    ├─ accessibilityStatusStreamProvider (watch for changes)
    │  └─ WatchAccessibilityStatusUseCase
    │     └─ AccessibilityRepository.watchAccessibilityStatus()
    │        └─ MethodChannelAccessibilityDataSource
    │           └─ Stream polling (5s interval) with error handling
    │
    └─ checkOverlayPermissionProvider
       └─ CheckOverlayPermissionUseCase
          └─ AccessibilityRepository.canDrawOverlays()
             └─ MethodChannelAccessibilityDataSource
                └─ MethodChannel → Kotlin canDrawOverlays()

SAFETY FEATURES:
  ✅ 2-second timeouts on all MethodChannel calls
  ✅ Safe defaults (return false if timeout)
  ✅ Error handling everywhere
  ✅ Async polling (non-blocking)
  ✅ Try-catch in providers

ENTITIES INVOLVED:
  • TaskStatus (lib/src/domain/entities/task_status.dart)
  • AccessibilityRepository (lib/src/domain/repositories/accessibility_repository.dart)
```

---

## Dependency Injection Wiring

```
service_locator.dart [ENTRY POINT]
    │
    ├─ Registers DATA SOURCES
    │  ├─ FirebaseRemoteTaskDataSource
    │  ├─ NativeMethodChannelAppDataSource
    │  ├─ SharedPreferencesBlockedAppsDataSource (init async in background)
    │  ├─ MethodChannelAccessibilityDataSource
    │  └─ InMemoryLocalTaskDataSource
    │
    ├─ Registers REPOSITORIES
    │  ├─ TaskRepositoryImpl (gets injected datasources)
    │  ├─ AppManagerRepositoryImpl
    │  ├─ BlockManagerRepositoryImpl
    │  └─ AccessibilityRepositoryImpl
    │
    └─ Registers USE CASES
       ├─ GetTasksUseCase (gets injected TaskRepository)
       ├─ SaveTaskUseCase
       ├─ DeleteTaskUseCase
       ├─ MarkTaskStatusUseCase
       ├─ GetCompletionStatsUseCase
       ├─ GetAllAppsUseCase
       ├─ GetUserAppsUseCase
       ├─ GetBlockedAppsUseCase
       ├─ WatchBlockedAppsUseCase
       ├─ BlockAppUseCase
       ├─ UnblockAppUseCase
       ├─ SetBlockedAppsUseCase
       ├─ CheckAccessibilityUseCase
       ├─ RequestAccessibilityUseCase
       ├─ CheckOverlayPermissionUseCase
       ├─ RequestOverlayPermissionUseCase
       ├─ WatchAccessibilityStatusUseCase
       └─ WatchAppOpeningEventsUseCase

HOW IT'S CALLED:
  main.dart → await setupServiceLocator() → getIt is now populated
  
  providers/*.dart → getIt<UseCase>() to get any use case
  
  UI → ref.watch(provider) which uses getIt internally
```

---

## Data Transformation Flow (Example: Task)

```
1. USER INTERACTION
   └─ Clicks "Save Task"

2. UI CALLS PROVIDER
   └─ ref.read(saveTaskProvider(task))

3. PROVIDER CALLS USE CASE
   └─ SaveTaskUseCase(task: Task)

4. USE CASE CALLS REPOSITORY
   └─ TaskRepository.saveTask(task: Task)

5. REPOSITORY CONVERTS TO DTO
   └─ Task → TaskDTO [via TaskMapper.toDTO()]
   
6. REPOSITORY CALLS DATA SOURCE
   └─ RemoteTaskDataSource.saveTask(taskDTO: TaskDTO)

7. DATA SOURCE SAVES TO FIRESTORE
   └─ taskDTO.toFirestore() → Map<String, dynamic>
   └─ firestore.collection('tasks').doc(id).set(map)

8. FIRESTORE NOTIFIES WATCHERS
   └─ RemoteTaskDataSource.watchTasks() stream emits

9. PROVIDER RECEIVES UPDATE
   └─ tasksStreamProvider receives TaskDTO list

10. MAPPER CONVERTS BACK TO ENTITIES
    └─ TaskDTO → Task [via TaskMapper.toDomain()]

11. PROVIDER EMITS TO UI
    └─ tasksStreamProvider: List<Task>

12. UI REBUILDS
    └─ Widget watches provider → rebuild with new data

LAYERS CROSSED:
  Presentation → Providers → Use Cases → Repository (interface)
  → Repository Impl → Data Sources → External (Firestore) → Back up
```

---

## Error Handling & Safety

```
┌─────────────────────────────────────────────────────┐
│ ACCESSIBILITY DATA SOURCE (highest risk)            │
│ • 2s timeout on all MethodChannel calls             │
│ • Try-catch with safe defaults                      │
│ • Async polling (non-blocking)                      │
│ • Stream error handling                             │
└─────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────┐
│ REPOSITORIES (catch errors from data sources)       │
│ • Delegate to data sources safely                   │
│ • Log errors                                        │
│ • Return safe defaults or throw DomainException    │
└─────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────┐
│ USE CASES (handle business logic errors)            │
│ • Validate inputs                                   │
│ • Catch repository exceptions                       │
│ • Throw DomainException if needed                   │
└─────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────┐
│ PROVIDERS (final UI safety net)                     │
│ • Try-catch wrapping entire use case calls          │
│ • Safe defaults (false, empty list, etc.)           │
│ • Show .error state in UI if needed                 │
│ • Never crash the app                              │
└─────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────┐
│ UI (always receives either data or safe value)      │
│ • No null/crash scenarios                           │
│ • Can render error states gracefully                │
└─────────────────────────────────────────────────────┘
```

---

## Testing Points (Where to Add Tests)

```
UNIT TESTS (easiest - no UI dependencies):
  ├─ Domain Entities (task.dart, blocked_app.dart, etc.)
  │  └─ Can instantiate and copyWith work
  │
  ├─ Use Cases (task_usecases.dart, etc.)
  │  └─ Mock repository, verify use case logic
  │  └─ Example: SaveTaskUseCase
  │     Mock: TaskRepository.saveTask()
  │     Test: Verify mapper called, repository called
  │
  └─ Mappers (task_mapper.dart, app_mapper.dart)
     └─ DTO → Entity → DTO should be lossless

INTEGRATION TESTS:
  ├─ Repository + Data Source
  │  └─ Mock Firestore, test repository implementation
  │  └─ Verify data source methods called correctly
  │
  └─ Data Source alone
     └─ Mock MethodChannel, test timeout behavior
     └─ Mock SharedPreferences, test persistence

WIDGET TESTS:
  ├─ Providers with test ProviderContainer
  │  └─ Override providers with fakes
  │  └─ Test async states (loading, data, error)
  │
  └─ Pages/Widgets consuming providers
     └─ Render with fake providers

GOLDEN TESTS:
  └─ Screenshot comparison of screens with different provider states
```

---

## Key Design Patterns Used

### 1. **Dependency Injection (get_it)**
   - Single `getIt` instance holds all registered dependencies
   - Called once in `main.dart` via `setupServiceLocator()`
   - Providers and use cases retrieve dependencies via `getIt<Type>()`

### 2. **Repository Pattern**
   - Interface in domain layer (abstract)
   - Implementation in data layer (concrete)
   - Repositories abstract data sources
   - Use cases depend on interfaces, not implementations

### 3. **Data Transfer Objects (DTOs)**
   - External format (Firestore JSON, MethodChannel maps)
   - Domain format (Task, BlockedApp entities)
   - Mappers convert between them

### 4. **Provider Pattern (Riverpod)**
   - Provides reactive state management
   - Automatic caching and rebuilds
   - Overrideable for testing
   - Composable (providers can depend on other providers)

### 5. **Use Case Pattern**
   - Single responsibility: one use case = one business action
   - Testable in isolation
   - Callable from anywhere (UI, other use cases)
   - Cleaner than services

### 6. **Error Handling Strategy**
   - Timeouts on external calls (MethodChannel)
   - Safe defaults on errors (false, empty list)
   - Try-catch at provider level
   - DomainException for business logic errors

---

**This is the complete interconnection map of all 38 new files!** 🎯


