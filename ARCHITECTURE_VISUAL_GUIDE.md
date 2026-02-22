# Modular Architecture - Visual Summary

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     USER INTERFACE (Riverpod)                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Widget (ConsumerWidget)                                    │ │
│  │  ├─ ref.watch(userAppsProvider)  ← Reactive updates      │ │
│  │  ├─ ref.read(blockAppProvider)   ← Mutations             │ │
│  │  └─ ref.watch(accessibilityStreamProvider) ← Streams     │ │
│  └────────────────────────────────────────────────────────────┘ │
└──────────────────────────┬──────────────────────────────────────┘
                           │ watches/reads
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│              PRESENTATION LAYER (Providers)                     │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ task_providers.dart                                        │ │
│  │ ├─ tasksStreamProvider: Stream<List<Task>>                │ │
│  │ ├─ saveTaskProvider: Future<void>                         │ │
│  │ └─ deleteTaskProvider: Future<void>                       │ │
│  ├─ app_providers.dart                                        │ │
│  │ ├─ userAppsProvider: Future<List<InstalledApplication>>   │ │
│  │ ├─ blockAppProvider: Future<void>                         │ │
│  │ └─ blockedAppsStreamProvider: Stream<List<BlockedApp>>    │ │
│  └─ accessibility_providers.dart                              │ │
│     ├─ checkAccessibilityProvider: Future<bool>              │ │
│     └─ accessibilityStatusStreamProvider: Stream<bool>       │ │
└──────────────────────────┬──────────────────────────────────────┘
                           │ calls
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│              DOMAIN LAYER (Business Logic)                      │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ USE CASES (Pure Functions)                                │ │
│  │ ├─ GetTasksUseCase(taskRepository)                        │ │
│  │ ├─ GetUserAppsUseCase(appRepository)                      │ │
│  │ ├─ BlockAppUseCase(blockRepository)                       │ │
│  │ └─ CheckAccessibilityUseCase(accessibilityRepository)     │ │
│  └─────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ REPOSITORIES (Interfaces - Contracts)                     │ │
│  │ ├─ TaskRepository                                         │ │
│  │ ├─ AppManagerRepository                                   │ │
│  │ ├─ BlockManagerRepository                                 │ │
│  │ └─ AccessibilityRepository                                │ │
│  └─────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ ENTITIES (Data Classes)                                   │ │
│  │ ├─ Task                                                   │ │
│  │ ├─ BlockedApp                                             │ │
│  │ └─ InstalledApplication                                   │ │
│  └────────────────────────────────────────────────────────────┘ │
└──────────────────────────┬──────────────────────────────────────┘
                           │ implements
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│               DATA LAYER (Implementation)                       │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ REPOSITORIES (Concrete Implementations)                   │ │
│  │ ├─ TaskRepositoryImpl(remoteDataSource, localDataSource)   │ │
│  │ ├─ AppManagerRepositoryImpl(remoteDataSource)              │ │
│  │ ├─ BlockManagerRepositoryImpl(localDataSource)             │ │
│  │ └─ AccessibilityRepositoryImpl(platformDataSource)         │ │
│  └─────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ DATA SOURCES (Interfaces & Implementations)               │ │
│  │ ├─ RemoteTaskDataSource                                   │ │
│  │ │  └─ FirebaseRemoteTaskDataSource (Firestore)            │ │
│  │ ├─ LocalTaskDataSource                                    │ │
│  │ │  └─ InMemoryLocalTaskDataSource (Cache)                 │ │
│  │ ├─ RemoteAppDataSource                                    │ │
│  │ │  └─ NativeMethodChannelAppDataSource (Kotlin)           │ │
│  │ ├─ LocalBlockedAppsDataSource                             │ │
│  │ │  └─ SharedPreferencesBlockedAppsDataSource              │ │
│  │ └─ AccessibilityPlatformDataSource                        │ │
│  │    └─ MethodChannelAccessibilityDataSource                │ │
│  └─────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ MAPPERS (DTO ↔ Entity Conversion)                         │ │
│  │ ├─ TaskMapper: TaskDTO ↔ Task                             │ │
│  │ ├─ InstalledApplicationMapper: DTO ↔ Entity               │ │
│  │ └─ BlockedAppMapper: DTO ↔ Entity                         │ │
│  └─────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ DTOs (Shape matching external sources)                    │ │
│  │ ├─ TaskDTO (Firestore shape)                              │ │
│  │ ├─ InstalledApplicationDTO (Native shape)                 │ │
│  │ └─ BlockedAppDTO (SharedPreferences shape)                │ │
│  └────────────────────────────────────────────────────────────┘ │
└──────────────────────────┬──────────────────────────────────────┘
                           │ accesses
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│            EXTERNAL DATA SOURCES & PLATFORMS                    │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ ☁️  Cloud Firestore (Remote Database)                     │ │
│  │ 📱 Native Kotlin via MethodChannel                        │ │
│  │ 💾 SharedPreferences (Local Storage)                      │ │
│  │ 🔗 HTTP APIs (if needed)                                  │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

                    DEPENDENCY INJECTION (get_it)
┌─────────────────────────────────────────────────────────────────┐
│ setupServiceLocator() - Registers all dependencies              │
│  ├─ Data sources                                                │
│  ├─ Repositories                                                │
│  └─ Use cases                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Dependency Flow

```
                    NO CIRCULAR DEPENDENCIES!
                    
Presentation → Domain ← Data
   (watches)  (uses)  (implements)
   
UI doesn't know about Data.
Data knows about Domain.
Domain doesn't import Flutter or external packages.

```

---

## Add New Feature: Steps

```
1. DOMAIN LAYER
   └─ Entity → Repository Interface → Use Cases

2. DATA LAYER
   └─ DTO → Mapper → Data Source → Repository Implementation

3. PRESENTATION LAYER
   └─ Riverpod Providers → UI Pages

4. CORE LAYER
   └─ Register in DI (service_locator.dart)

5. TEST
   └─ Unit tests → Integration tests
```

---

## Key Files Quick Reference

| File | Purpose | Example |
|------|---------|---------|
| `domain/entities/` | Pure data classes | `Task`, `BlockedApp` |
| `domain/repositories/` | Contracts/interfaces | `TaskRepository` |
| `domain/usecases/` | Business logic | `GetTasksUseCase` |
| `data/dtos/` | External shape mapping | `TaskDTO` |
| `data/mappers/` | DTO ↔ Entity conversion | `TaskMapper` |
| `data/datasources/` | Data access interfaces | `RemoteTaskDataSource` |
| `data/datasources/implementations/` | Concrete implementations | `FirebaseRemoteTaskDataSource` |
| `data/repositories/` | Repo implementations | `TaskRepositoryImpl` |
| `presentation/providers/` | Riverpod state | `tasksStreamProvider` |
| `presentation/pages/` | Full-screen UI | `FocusPage` |
| `core/service_locator.dart` | DI registration | `setupServiceLocator()` |

---

## Riverpod Provider Types

```dart
// READ-ONLY: Watch a use case
final userAppsProvider = FutureProvider<List<InstalledApplication>>((ref) {
  return ref.watch(getUserAppsUseCaseProvider)();
});

// STREAM: Watch real-time updates
final blockedAppsStreamProvider = StreamProvider<List<BlockedApp>>((ref) {
  return ref.watch(watchBlockedAppsUseCaseProvider)();
});

// MUTATION: Perform action and invalidate
final blockAppProvider = FutureProvider.family<void, BlockedApp>((ref, app) async {
  await ref.watch(blockAppUseCaseProvider)(app);
  ref.invalidate(blockedAppsStreamProvider);  // Refresh UI
});

// COMPUTED: Combine multiple providers
final filteredAppsProvider = Provider<List<InstalledApplication>>((ref) {
  final allApps = ref.watch(userAppsProvider);
  final blockedApps = ref.watch(blockedAppsStreamProvider);
  
  return allApps.when(
    data: (apps) => blockedApps.when(
      data: (blocked) => apps.where((a) =>
        !blocked.any((b) => b.packageName == a.packageName)
      ).toList(),
      ...
    ),
    ...
  );
});
```

---

## Testing Strategy

```
UNIT TESTS (Domain & Data)
├─ Use Cases
│  └─ Test business logic with mocked repositories
├─ Repositories
│  └─ Test mapping and error handling
└─ Mappers
   └─ Test DTO ↔ Entity conversion

WIDGET TESTS (Presentation)
├─ Providers
│  └─ Test with ProviderContainer overrides
└─ Pages
   └─ Test UI with mock data

INTEGRATION TESTS
└─ End-to-end user flows
```

---

## Best Practices Checklist

- ✅ Domain layer has NO external imports (no Flutter, no Firebase)
- ✅ Data layer implements domain interfaces
- ✅ Presentation layer uses Riverpod providers
- ✅ All dependencies registered in `service_locator.dart`
- ✅ DTOs converted to entities at layer boundaries
- ✅ Use-cases have single responsibility
- ✅ Repositories abstract data sources
- ✅ Error handling throughout stack
- ✅ Tests for domain and data layers
- ✅ No business logic in widgets

---

## Migration Checklist

```
PHASE 1: Foundation (DONE ✅)
  ✅ Domain layer created
  ✅ Data layer created
  ✅ Presentation setup
  ✅ DI configured

PHASE 2: Pages (IN PROGRESS 🔄)
  ✅ FocusPage refactored
  ⏳ Home, AddTask, Stats, Profile (placeholders)

PHASE 3: Services (TODO ⏳)
  ⏳ Remove old service files
  ⏳ Update imports

PHASE 4: Testing (TODO ⏳)
  ⏳ Add unit tests
  ⏳ Add widget tests
  ⏳ Add integration tests

PHASE 5: Polish (TODO ⏳)
  ⏳ Code review
  ⏳ Performance optimization
  ⏳ Documentation
```

---

## Common Questions

**Q: Where does my business logic go?**
A: In use-cases (`domain/usecases/`)

**Q: How do I access data from UI?**
A: Through Riverpod providers (`presentation/providers/`)

**Q: How do I test?**
A: Mock repositories for use-cases, override providers for widgets

**Q: Can I use GetIt without Riverpod?**
A: Yes, but Riverpod is better for reactive UI

**Q: How do I handle errors?**
A: Define domain errors, map to UI errors in providers

---

Enjoy your clean architecture! 🚀

