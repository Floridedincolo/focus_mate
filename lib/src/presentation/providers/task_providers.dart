import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_completion_status.dart';
import '../../domain/usecases/task_usecases.dart';
import '../../domain/usecases/notification_usecases.dart';
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

/// Re-schedules all notifications only if the user has them enabled.
Future<void> _refreshNotifications() async {
  final enabled = await getIt<GetNotificationsEnabledUseCase>()();
  if (enabled) {
    await getIt<ToggleNotificationsUseCase>().scheduleAll();
  }
}

/// Future provider for creating/updating a task
final saveTaskProvider =
    FutureProvider.family<void, Task>((ref, task) async {
  final usecase = ref.watch(saveTaskUseCaseProvider);
  await usecase(task);
  ref.invalidate(tasksStreamProvider);
  await _refreshNotifications();
});

/// Future provider for deleting a task
final deleteTaskProvider =
    FutureProvider.family<void, String>((ref, taskId) async {
  final usecase = ref.watch(deleteTaskUseCaseProvider);
  await usecase(taskId);
  ref.invalidate(tasksStreamProvider);
  await _refreshNotifications();
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

/// Returns the currently active task based on the current time.
///
/// A task is considered "active" right now if:
/// - It is not archived
/// - Its startTime <= now <= endTime
/// - It is scheduled for today (based on days map or one-time date)
///
/// Returns `null` if no task is currently active.
final currentActiveTaskProvider = Provider<Task?>((ref) {
  final tasksAsync = ref.watch(tasksStreamProvider);
  return tasksAsync.maybeWhen(
    data: (tasks) {
      final now = DateTime.now();
      final todayKey = _dayKeyFromWeekday(now.weekday);
      final nowMinutes = now.hour * 60 + now.minute;

      for (final task in tasks) {
        if (task.archived) continue;
        if (task.startTime == null || task.endTime == null) continue;

        // Check if the task occurs today
        final occursToday = _taskOccursToday(task, now, todayKey);
        if (!occursToday) continue;

        // Check if current time is within task's time range
        final startMinutes = task.startTime!.hour * 60 + task.startTime!.minute;
        final endMinutes = task.endTime!.hour * 60 + task.endTime!.minute;

        if (nowMinutes >= startMinutes && nowMinutes <= endMinutes) {
          return task;
        }
      }
      return null;
    },
    orElse: () => null,
  );
});

String _dayKeyFromWeekday(int weekday) {
  const dayKeys = [
    '', // 0 - not used
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];
  return dayKeys[weekday];
}

bool _taskOccursToday(Task task, DateTime now, String todayKey) {
  // One-time tasks: check if startDate matches today
  if (task.oneTime) {
    return task.startDate.year == now.year &&
        task.startDate.month == now.month &&
        task.startDate.day == now.day;
  }

  // Recurring tasks: check the days map
  if (task.days.isNotEmpty) {
    return task.days[todayKey] == true;
  }

  // Daily tasks (no days specified, not one-time)
  return true;
}
