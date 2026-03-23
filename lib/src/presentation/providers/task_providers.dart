import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_completion_status.dart';
import '../../domain/usecases/task_usecases.dart';
import '../../data/datasources/task_data_source.dart';
import '../../core/service_locator.dart';
import 'friend_providers.dart'; // for currentUserUidProvider

/// Provider for GetTasksUseCase
final getTasksUseCaseProvider = Provider<GetTasksUseCase>(
  (ref) => getIt<GetTasksUseCase>(),
);

/// Provider for SaveTaskUseCase
final saveTaskUseCaseProvider = Provider<SaveTaskUseCase>(
  (ref) => getIt<SaveTaskUseCase>(),
);

/// Provider for DeleteTaskUseCase
final deleteTaskUseCaseProvider = Provider<DeleteTaskUseCase>(
  (ref) => getIt<DeleteTaskUseCase>(),
);

/// Provider for MarkTaskStatusUseCase
final markTaskStatusUseCaseProvider = Provider<MarkTaskStatusUseCase>(
  (ref) => getIt<MarkTaskStatusUseCase>(),
);

/// Provider for ClearCompletionUseCase
final clearCompletionUseCaseProvider = Provider<ClearCompletionUseCase>(
  (ref) => getIt<ClearCompletionUseCase>(),
);

/// Stream provider for watching tasks.
///
/// Watches [currentUserUidProvider] so the stream automatically resets
/// (new Firestore listener for the new UID) whenever the user signs in,
/// signs out, or switches accounts.  The local in-memory cache is also
/// cleared to prevent stale data from a previous user leaking through.
final tasksStreamProvider = StreamProvider<List<Task>>((ref) {
  final uid = ref.watch(currentUserUidProvider);

  // Clear the local cache so a new user never sees stale tasks.
  getIt<LocalTaskDataSource>().clearCache();

  // If there is no signed-in user, emit an empty list.
  if (uid == null) return const Stream.empty();

  final usecase = ref.watch(getTasksUseCaseProvider);
  return usecase();
});

/// Future provider for creating/updating a task
final saveTaskProvider =
    FutureProvider.family<void, Task>((ref, task) async {
  final usecase = ref.watch(saveTaskUseCaseProvider);
  await usecase(task);
  ref.invalidate(tasksStreamProvider);
});

/// Future provider for deleting a task
final deleteTaskProvider =
    FutureProvider.family<void, String>((ref, taskId) async {
  final usecase = ref.watch(deleteTaskUseCaseProvider);
  await usecase(taskId);
  ref.invalidate(tasksStreamProvider);
});

/// Future provider for marking task status
/// Parameters: (Task, DateTime, TaskCompletionStatus)
final markTaskStatusProvider =
    FutureProvider.family<int, (Task, DateTime, TaskCompletionStatus)>((ref, params) {
  final usecase = ref.watch(markTaskStatusUseCaseProvider);
  return usecase(params.$1, params.$2, params.$3);
});

/// Future provider for clearing a completion
/// Parameters: (Task, DateTime)
final clearCompletionProvider =
    FutureProvider.family<int, (Task, DateTime)>((ref, params) {
  final usecase = ref.watch(clearCompletionUseCaseProvider);
  return usecase(params.$1, params.$2);
});

