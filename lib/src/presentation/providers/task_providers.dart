import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/task.dart';
import '../../domain/usecases/task_usecases.dart';
import '../../core/service_locator.dart';

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

/// Stream provider for watching tasks
final tasksStreamProvider = StreamProvider<List<Task>>((ref) {
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
/// Parameters: (Task, DateTime, String status)
final markTaskStatusProvider =
    FutureProvider.family<int, (Task, DateTime, String)>((ref, params) {
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

