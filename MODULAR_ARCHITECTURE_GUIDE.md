# Modular Architecture Refactoring Guide

## Overview

This refactoring organizes the codebase into a clean, layered architecture:

```
lib/src/
├── domain/          # Business logic (entities, interfaces, use-cases)
├── data/            # Data layer (DTOs, mappers, repositories impl, data sources)
├── presentation/    # UI layer (pages, widgets, providers)
└── core/            # Core utilities (DI, exceptions, etc.)
```

## Architecture Layers

### 1. Domain Layer (`lib/src/domain/`)
**Purpose**: Contains pure business logic, independent of frameworks.

- **entities/**: Data classes representing core domain concepts
  - `task.dart` - Task entity
  - `task_status.dart` - Task status tracking
  - `blocked_app.dart` - Blocked app entity
  - `installed_application.dart` - System app entity

- **repositories/**: Interfaces (contracts) that data layer must implement
  - `task_repository.dart` - Task operations interface
  - `app_manager_repository.dart` - App management interface
  - `block_manager_repository.dart` - App blocking interface
  - `accessibility_repository.dart` - Accessibility interface

- **usecases/**: Business logic wrapped in reusable classes
  - `task_usecases.dart` - All task-related use cases
  - `app_usecases.dart` - All app-related use cases
  - `accessibility_usecases.dart` - All accessibility use cases

- **errors/**: Domain-specific exceptions
  - `domain_errors.dart` - Sealed exception classes

### 2. Data Layer (`lib/src/data/`)
**Purpose**: Implements repositories and manages data sources.

- **dtos/**: Data Transfer Objects (match network/DB shapes)
  - `task_dto.dart` - Task DTO with Firestore conversion
  - `app_dto.dart` - App-related DTOs

- **mappers/**: Convert DTOs ↔ Domain Entities
  - `task_mapper.dart` - Task entity mapping
  - `app_mapper.dart` - App entity mapping

- **datasources/**: Interfaces for data sources
  - `task_data_source.dart` - Remote & local task data interfaces
  - `app_data_source.dart` - App & blocking data interfaces
  - `accessibility_data_source.dart` - Accessibility interface

- **datasources/implementations/**: Concrete implementations
  - `firestore_task_datasource.dart` - Firebase impl
  - `native_app_datasource.dart` - MethodChannel impl for native
  - `shared_preferences_datasource.dart` - SharedPreferences impl
  - `method_channel_accessibility_datasource.dart` - Accessibility impl

- **repositories/**: Concrete repository implementations
  - `task_repository_impl.dart` - Implements TaskRepository
  - `app_repository_impl.dart` - Implements AppManager & BlockManager
  - `accessibility_repository_impl.dart` - Implements AccessibilityRepository

### 3. Presentation Layer (`lib/src/presentation/`)
**Purpose**: UI and state management using Riverpod.

- **pages/**: Full-screen widgets
  - `main_page.dart` - Main navigation shell
  - `focus_page.dart` - Example refactored page with Riverpod
  - `home.dart`, `add_task.dart`, `stats_page.dart`, `profile.dart`

- **providers/**: Riverpod providers for state & data
  - `task_providers.dart` - Task state providers
  - `app_providers.dart` - App blocking state providers
  - `accessibility_providers.dart` - Accessibility state providers

- **widgets/**: Reusable UI components

### 4. Core Layer (`lib/src/core/`)
**Purpose**: Shared utilities and dependency injection.

- `service_locator.dart` - get_it DI setup and initialization

## Key Patterns

### 1. Dependency Injection (get_it)

All dependencies registered in `setupServiceLocator()`:

```dart
// In main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(...);
  await setupServiceLocator();  // ← Initialize DI
  runApp(const ProviderScope(child: FocusMateApp()));
}
```

### 2. Use Cases

Wrap business logic in single-responsibility use-cases:

```dart
// domain/usecases/app_usecases.dart
class GetUserAppsUseCase {
  final AppManagerRepository _repository;
  
  GetUserAppsUseCase(this._repository);
  
  Future<List<InstalledApplication>> call() {
    return _repository.getUserApps();
  }
}
```

**Why**: Easy to test, compose, and reuse across UI frameworks.

### 3. Mappers

Convert between DTOs and Entities at layer boundaries:

```dart
// data/mappers/app_mapper.dart
class InstalledApplicationMapper {
  static InstalledApplication toDomain(InstalledApplicationDTO dto) {
    // Decode base64 icons, transform data, etc.
    return InstalledApplication(...);
  }
}
```

**Why**: DTOs match external shapes (Firestore, APIs); entities are domain-clean.

### 4. Riverpod Providers

State management with compile-time safety and testability:

```dart
// presentation/providers/app_providers.dart
final userAppsProvider = FutureProvider<List<InstalledApplication>>((ref) {
  final usecase = ref.watch(getUserAppsUseCaseProvider);
  return usecase();
});

// In widget:
final apps = ref.watch(userAppsProvider);
apps.when(
  data: (list) => ListView(...),
  loading: () => CircularProgressIndicator(),
  error: (e, st) => Text('Error: $e'),
);
```

**Why**: Automatic rebuilds, caching, error handling, testable.

## Migration Checklist

### Phase 1: High-Impact Setup (Already Done ✅)
- [x] Create domain layer (entities, repositories, use-cases)
- [x] Create data layer (DTOs, mappers, data sources, implementations)
- [x] Create presentation layer structure (pages, providers)
- [x] Set up DI with get_it
- [x] Set up Riverpod
- [x] Add dependencies to pubspec.yaml

### Phase 2: Migrate Pages (In Progress)
- [x] Refactor FocusPage to use Riverpod providers
- [ ] Refactor Home page
- [ ] Refactor AddTask page
- [ ] Refactor Stats page
- [ ] Refactor Profile page

### Phase 3: Migrate Services
- [ ] Replace old `accessibility_service.dart` with domain interfaces
- [ ] Replace old `app_manager_service.dart` with domain interfaces
- [ ] Replace old `block_app_manager.dart` with domain interfaces
- [ ] Replace old `firestore_service.dart` usage

### Phase 4: Testing
- [ ] Add unit tests for use-cases
- [ ] Add repository tests with mock data sources
- [ ] Add widget tests for pages
- [ ] Add integration tests

### Phase 5: Polish
- [ ] Remove old service files after migration complete
- [ ] Remove old page files (keep as reference in docs/)
- [ ] Update imports across app
- [ ] Run full app test

## Example: Adding a New Feature

Let's say you want to add "Task Categories":

### 1. Domain (Business rules)
```dart
// domain/entities/task_category.dart
class TaskCategory {
  final String id;
  final String name;
  
  TaskCategory({required this.id, required this.name});
}

// domain/repositories/task_category_repository.dart
abstract class TaskCategoryRepository {
  Stream<List<TaskCategory>> watchCategories();
  Future<void> saveCategory(TaskCategory cat);
}

// domain/usecases/task_category_usecases.dart
class GetCategoriesUseCase {
  final TaskCategoryRepository _repo;
  GetCategoriesUseCase(this._repo);
  
  Stream<List<TaskCategory>> call() => _repo.watchCategories();
}
```

### 2. Data (Implementation)
```dart
// data/dtos/task_category_dto.dart
class TaskCategoryDTO { ... }

// data/mappers/task_category_mapper.dart
class TaskCategoryMapper { ... }

// data/datasources/task_category_data_source.dart (interface)
// data/datasources/implementations/firestore_category_datasource.dart (impl)

// data/repositories/task_category_repository_impl.dart
class TaskCategoryRepositoryImpl implements TaskCategoryRepository { ... }
```

### 3. Presentation (UI)
```dart
// presentation/providers/task_category_providers.dart
final categoriesProvider = StreamProvider<List<TaskCategory>>((ref) {
  return ref.watch(getCategoriesUseCaseProvider)();
});

// presentation/pages/task_category_page.dart
class TaskCategoryPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    return categories.when(
      data: (cats) => ListView(...),
      ...
    );
  }
}
```

### 4. DI (Register)
```dart
// core/service_locator.dart
getIt.registerSingleton<TaskCategoryRepository>(
  TaskCategoryRepositoryImpl(
    remoteDataSource: getIt<RemoteTaskCategoryDataSource>(),
  ),
);
getIt.registerSingleton(GetCategoriesUseCase(getIt<TaskCategoryRepository>()));
```

**Benefits**:
- Business logic (domain) is testable without UI
- Data sources (Firestore, API, etc.) are replaceable
- UI (Riverpod) is simple and reactive
- Easy to test each layer independently

## Testing Examples

### Unit Test: Use Case
```dart
// test/domain/usecases/get_user_apps_usecases_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GetUserAppsUseCase', () {
    test('returns user apps from repository', () async {
      // Arrange
      final mockRepo = MockAppManagerRepository();
      final usecase = GetUserAppsUseCase(mockRepo);
      final apps = [/* test data */];
      when(mockRepo.getUserApps()).thenAnswer((_) async => apps);

      // Act
      final result = await usecase();

      // Assert
      expect(result, apps);
      verify(mockRepo.getUserApps()).called(1);
    });
  });
}
```

### Widget Test: Riverpod Provider
```dart
// test/presentation/pages/focus_page_test.dart
void main() {
  testWidgets('FocusPage displays blocked apps', (tester) async {
    await tester.pumpWidget(
      ProviderContainer(
        overrides: [
          blockedAppsProvider.overrideWith((ref) =>
              AsyncValue.data([/* test apps */])),
        ],
        child: const FocusPageWidget(),
      ),
    );

    expect(find.text('Blocked Apps'), findsOneWidget);
  });
}
```

## Best Practices Going Forward

1. **Keep domain pure**: No Flutter imports in `domain/`
2. **Use DTOs for external data**: Never expose raw API/DB responses
3. **One responsibility per use-case**: `GetUserAppsUseCase`, not `GetUserAppsAndBlockedAppsUseCase`
4. **Provider composition**: Combine providers, don't duplicate logic
5. **Error handling**: Use domain errors, map to UI errors in presentation
6. **DI at bootstrap**: `setupServiceLocator()` in `main()`, nothing else
7. **Test pyramid**: Many unit tests, fewer integration tests

## Next Steps

1. Run `flutter pub get` to install new dependencies
2. Run the app: `flutter run` (main.dart now uses Riverpod)
3. Test FocusPage refactor (already using new architecture)
4. Gradually migrate remaining pages following the same pattern
5. Add unit and widget tests as you go

## Troubleshooting

**Q: "Provider not found" error?**
A: Make sure app is wrapped with `ProviderScope(child: YourApp())`

**Q: "GetIt instance not set up?"**
A: Call `await setupServiceLocator()` in `main()` before `runApp()`

**Q: Old vs new pages?**
A: Old pages in `lib/pages/` are still available. Migrate gradually to `lib/src/presentation/pages/`

**Q: How to test providers?**
A: Use `ProviderContainer(overrides: [...])`  for fine-grained testing

---

Enjoy your modular, testable, scalable architecture! 🚀

