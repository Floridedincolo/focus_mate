# Quick Start: Adding New Features to Modular Architecture

## Template for Adding a New Feature

Let's say you want to add **"Task Reminders"** feature. Here's the exact pattern to follow:

---

## Step 1: Create Domain Entity

**File**: `lib/src/domain/entities/task_reminder.dart`

```dart
class TaskReminder {
  final String id;
  final String taskId;
  final DateTime scheduledTime;
  final String message;
  final bool isActive;

  TaskReminder({
    required this.id,
    required this.taskId,
    required this.scheduledTime,
    required this.message,
    required this.isActive,
  });

  TaskReminder copyWith({
    String? id,
    String? taskId,
    DateTime? scheduledTime,
    String? message,
    bool? isActive,
  }) {
    return TaskReminder(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      message: message ?? this.message,
      isActive: isActive ?? this.isActive,
    );
  }
}
```

---

## Step 2: Create Repository Interface

**File**: `lib/src/domain/repositories/task_reminder_repository.dart`

```dart
import '../entities/task_reminder.dart';

abstract class TaskReminderRepository {
  /// Watch all reminders as a stream
  Stream<List<TaskReminder>> watchReminders();

  /// Get reminder by ID
  Future<TaskReminder?> getReminder(String id);

  /// Save/update reminder
  Future<void> saveReminder(TaskReminder reminder);

  /// Delete reminder
  Future<void> deleteReminder(String id);

  /// Get reminders for a specific task
  Stream<List<TaskReminder>> watchRemindersByTask(String taskId);
}
```

---

## Step 3: Create Use Cases

**File**: `lib/src/domain/usecases/task_reminder_usecases.dart`

```dart
import '../repositories/task_reminder_repository.dart';
import '../entities/task_reminder.dart';

class GetRemindersUseCase {
  final TaskReminderRepository _repository;
  GetRemindersUseCase(this._repository);

  Stream<List<TaskReminder>> call() {
    return _repository.watchReminders();
  }
}

class SaveReminderUseCase {
  final TaskReminderRepository _repository;
  SaveReminderUseCase(this._repository);

  Future<void> call(TaskReminder reminder) {
    return _repository.saveReminder(reminder);
  }
}

class DeleteReminderUseCase {
  final TaskReminderRepository _repository;
  DeleteReminderUseCase(this._repository);

  Future<void> call(String reminderId) {
    return _repository.deleteReminder(reminderId);
  }
}

class GetTaskRemindersUseCase {
  final TaskReminderRepository _repository;
  GetTaskRemindersUseCase(this._repository);

  Stream<List<TaskReminder>> call(String taskId) {
    return _repository.watchRemindersByTask(taskId);
  }
}
```

---

## Step 4: Create DTOs

**File**: `lib/src/data/dtos/task_reminder_dto.dart`

```dart
class TaskReminderDTO {
  final String id;
  final String taskId;
  final DateTime scheduledTime;
  final String message;
  final bool isActive;

  TaskReminderDTO({
    required this.id,
    required this.taskId,
    required this.scheduledTime,
    required this.message,
    required this.isActive,
  });

  /// From Firestore
  factory TaskReminderDTO.fromFirestore(Map<String, dynamic> data) {
    return TaskReminderDTO(
      id: data['id'] as String? ?? '',
      taskId: data['taskId'] as String? ?? '',
      scheduledTime: (data['scheduledTime'] != null)
          ? DateTime.parse(data['scheduledTime'] as String)
          : DateTime.now(),
      message: data['message'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  /// To Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'taskId': taskId,
      'scheduledTime': scheduledTime.toIso8601String(),
      'message': message,
      'isActive': isActive,
    };
  }

  TaskReminderDTO copyWith({
    String? id,
    String? taskId,
    DateTime? scheduledTime,
    String? message,
    bool? isActive,
  }) {
    return TaskReminderDTO(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      message: message ?? this.message,
      isActive: isActive ?? this.isActive,
    );
  }
}
```

---

## Step 5: Create Mapper

**File**: `lib/src/data/mappers/task_reminder_mapper.dart`

```dart
import '../../domain/entities/task_reminder.dart';
import '../dtos/task_reminder_dto.dart';

class TaskReminderMapper {
  static TaskReminder toDomain(TaskReminderDTO dto) {
    return TaskReminder(
      id: dto.id,
      taskId: dto.taskId,
      scheduledTime: dto.scheduledTime,
      message: dto.message,
      isActive: dto.isActive,
    );
  }

  static TaskReminderDTO toDTO(TaskReminder entity) {
    return TaskReminderDTO(
      id: entity.id,
      taskId: entity.taskId,
      scheduledTime: entity.scheduledTime,
      message: entity.message,
      isActive: entity.isActive,
    );
  }

  static List<TaskReminder> toDomainList(List<TaskReminderDTO> dtos) {
    return dtos.map(toDomain).toList();
  }

  static List<TaskReminderDTO> toDTOList(List<TaskReminder> entities) {
    return entities.map(toDTO).toList();
  }
}
```

---

## Step 6: Create Data Source Interfaces

**File**: `lib/src/data/datasources/task_reminder_data_source.dart`

```dart
import '../dtos/task_reminder_dto.dart';

abstract class RemoteTaskReminderDataSource {
  Stream<List<TaskReminderDTO>> watchReminders();
  Future<TaskReminderDTO?> getReminder(String id);
  Future<void> saveReminder(TaskReminderDTO reminder);
  Future<void> deleteReminder(String id);
  Stream<List<TaskReminderDTO>> watchRemindersByTask(String taskId);
}
```

---

## Step 7: Create Data Source Implementation

**File**: `lib/src/data/datasources/implementations/firestore_reminder_datasource.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../task_reminder_data_source.dart';
import '../../dtos/task_reminder_dto.dart';

class FirebaseRemoteTaskReminderDataSource
    implements RemoteTaskReminderDataSource {
  final FirebaseFirestore _firestore;
  static const _collection = 'task_reminders';

  FirebaseRemoteTaskReminderDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<TaskReminderDTO>> watchReminders() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) =>
              TaskReminderDTO.fromFirestore({...doc.data(), 'id': doc.id}))
          .toList();
    });
  }

  @override
  Future<TaskReminderDTO?> getReminder(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (!doc.exists) return null;
    return TaskReminderDTO.fromFirestore({...doc.data()!, 'id': doc.id});
  }

  @override
  Future<void> saveReminder(TaskReminderDTO reminder) {
    return _firestore
        .collection(_collection)
        .doc(reminder.id)
        .set(reminder.toFirestore());
  }

  @override
  Future<void> deleteReminder(String id) {
    return _firestore.collection(_collection).doc(id).delete();
  }

  @override
  Stream<List<TaskReminderDTO>> watchRemindersByTask(String taskId) {
    return _firestore
        .collection(_collection)
        .where('taskId', isEqualTo: taskId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) =>
              TaskReminderDTO.fromFirestore({...doc.data(), 'id': doc.id}))
          .toList();
    });
  }
}
```

---

## Step 8: Create Repository Implementation

**File**: `lib/src/data/repositories/task_reminder_repository_impl.dart`

```dart
import '../../domain/repositories/task_reminder_repository.dart';
import '../../domain/entities/task_reminder.dart';
import '../datasources/task_reminder_data_source.dart';
import '../mappers/task_reminder_mapper.dart';

class TaskReminderRepositoryImpl implements TaskReminderRepository {
  final RemoteTaskReminderDataSource remoteDataSource;

  TaskReminderRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<TaskReminder>> watchReminders() {
    return remoteDataSource
        .watchReminders()
        .map(TaskReminderMapper.toDomainList);
  }

  @override
  Future<TaskReminder?> getReminder(String id) async {
    final dto = await remoteDataSource.getReminder(id);
    return dto != null ? TaskReminderMapper.toDomain(dto) : null;
  }

  @override
  Future<void> saveReminder(TaskReminder reminder) {
    final dto = TaskReminderMapper.toDTO(reminder);
    return remoteDataSource.saveReminder(dto);
  }

  @override
  Future<void> deleteReminder(String id) {
    return remoteDataSource.deleteReminder(id);
  }

  @override
  Stream<List<TaskReminder>> watchRemindersByTask(String taskId) {
    return remoteDataSource
        .watchRemindersByTask(taskId)
        .map(TaskReminderMapper.toDomainList);
  }
}
```

---

## Step 9: Create Riverpod Providers

**File**: `lib/src/presentation/providers/task_reminder_providers.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/task_reminder.dart';
import '../../domain/usecases/task_reminder_usecases.dart';
import '../../core/service_locator.dart';

final getRemindersUseCaseProvider = Provider<GetRemindersUseCase>(
  (ref) => getIt<GetRemindersUseCase>(),
);

final saveReminderUseCaseProvider = Provider<SaveReminderUseCase>(
  (ref) => getIt<SaveReminderUseCase>(),
);

final deleteReminderUseCaseProvider = Provider<DeleteReminderUseCase>(
  (ref) => getIt<DeleteReminderUseCase>(),
);

final getTaskRemindersUseCaseProvider = Provider<GetTaskRemindersUseCase>(
  (ref) => getIt<GetTaskRemindersUseCase>(),
);

// Stream: Watch all reminders
final remindersStreamProvider = StreamProvider<List<TaskReminder>>((ref) {
  final usecase = ref.watch(getRemindersUseCaseProvider);
  return usecase();
});

// Future: Save reminder
final saveReminderProvider =
    FutureProvider.family<void, TaskReminder>((ref, reminder) async {
  final usecase = ref.watch(saveReminderUseCaseProvider);
  await usecase(reminder);
  ref.invalidate(remindersStreamProvider);
});

// Future: Delete reminder
final deleteReminderProvider =
    FutureProvider.family<void, String>((ref, reminderId) async {
  final usecase = ref.watch(deleteReminderUseCaseProvider);
  await usecase(reminderId);
  ref.invalidate(remindersStreamProvider);
});

// Stream: Watch reminders for a task
final taskRemindersProvider =
    StreamProvider.family<List<TaskReminder>, String>((ref, taskId) {
  final usecase = ref.watch(getTaskRemindersUseCaseProvider);
  return usecase(taskId);
});
```

---

## Step 10: Register in DI

**File**: `lib/src/core/service_locator.dart` (Add to `setupServiceLocator()`)

```dart
// Add this inside setupServiceLocator()

// Data Sources
getIt.registerSingleton<RemoteTaskReminderDataSource>(
  FirebaseRemoteTaskReminderDataSource(firestore: FirebaseFirestore.instance),
);

// Repositories
getIt.registerSingleton<TaskReminderRepository>(
  TaskReminderRepositoryImpl(
    remoteDataSource: getIt<RemoteTaskReminderDataSource>(),
  ),
);

// Use Cases
getIt.registerSingleton(GetRemindersUseCase(getIt<TaskReminderRepository>()));
getIt.registerSingleton(SaveReminderUseCase(getIt<TaskReminderRepository>()));
getIt.registerSingleton(DeleteReminderUseCase(getIt<TaskReminderRepository>()));
getIt.registerSingleton(GetTaskRemindersUseCase(getIt<TaskReminderRepository>()));
```

---

## Step 11: Use in UI

**File**: `lib/src/presentation/pages/task_reminders_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/task_reminder.dart';
import '../providers/task_reminder_providers.dart';

class TaskRemindersPage extends ConsumerWidget {
  final String taskId;

  const TaskRemindersPage({required this.taskId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(taskRemindersProvider(taskId));

    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: reminders.when(
        data: (reminderList) => ListView.builder(
          itemCount: reminderList.length,
          itemBuilder: (context, index) {
            final reminder = reminderList[index];
            return ListTile(
              title: Text(reminder.message),
              subtitle: Text(reminder.scheduledTime.toString()),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  await ref.read(
                    deleteReminderProvider(reminder.id).future,
                  );
                },
              ),
            );
          },
        ),
        loading: () => const CircularProgressIndicator(),
        error: (error, st) => Text('Error: $error'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Create new reminder
          final newReminder = TaskReminder(
            id: DateTime.now().toString(),
            taskId: taskId,
            scheduledTime: DateTime.now().add(const Duration(hours: 1)),
            message: 'Reminder',
            isActive: true,
          );
          ref.read(saveReminderProvider(newReminder));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

---

## Checklist

- [ ] Create entity
- [ ] Create repository interface
- [ ] Create use-cases
- [ ] Create DTOs
- [ ] Create mapper
- [ ] Create data source interface
- [ ] Create data source implementation
- [ ] Create repository implementation
- [ ] Create Riverpod providers
- [ ] Register in DI
- [ ] Create UI page(s)
- [ ] Test use-case with mocks
- [ ] Test repository with mock data source
- [ ] Test widget

---

## Testing Template

**File**: `test/domain/usecases/task_reminder_usecases_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:focus_mate/src/domain/entities/task_reminder.dart';
import 'package:focus_mate/src/domain/repositories/task_reminder_repository.dart';
import 'package:focus_mate/src/domain/usecases/task_reminder_usecases.dart';

class MockTaskReminderRepository extends Mock
    implements TaskReminderRepository {}

void main() {
  group('TaskReminderUseCases', () {
    late MockTaskReminderRepository mockRepository;
    late SaveReminderUseCase saveUseCase;

    setUp(() {
      mockRepository = MockTaskReminderRepository();
      saveUseCase = SaveReminderUseCase(mockRepository);
    });

    test('SaveReminderUseCase saves reminder', () async {
      // Arrange
      final reminder = TaskReminder(
        id: '1',
        taskId: 'task1',
        scheduledTime: DateTime.now(),
        message: 'Test reminder',
        isActive: true,
      );
      when(mockRepository.saveReminder(reminder))
          .thenAnswer((_) async => {});

      // Act
      await saveUseCase(reminder);

      // Assert
      verify(mockRepository.saveReminder(reminder)).called(1);
    });
  });
}
```

---

## Summary

Follow this pattern for **every new feature**:

1. ✅ Domain: Entity + Repository interface + Use-cases
2. ✅ Data: DTO + Mapper + DataSource interface + Implementation + Repository impl
3. ✅ Presentation: Riverpod providers + UI pages
4. ✅ Core: Register in DI
5. ✅ Test: Unit tests for use-case, repository

**You now have a scalable, testable feature architecture!** 🚀

