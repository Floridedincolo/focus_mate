import '../repositories/notification_repository.dart';
import '../repositories/task_repository.dart';

class ToggleNotificationsUseCase {
  final NotificationRepository _notificationRepo;
  final TaskRepository _taskRepo;

  const ToggleNotificationsUseCase(this._notificationRepo, this._taskRepo);

  /// Toggle from profile: ON schedules all, OFF cancels all.
  Future<void> call(bool enable) async {
    await _notificationRepo.setNotificationsEnabled(enable);
    if (enable) {
      await scheduleAll();
    } else {
      await _notificationRepo.cancelAllNotifications();
    }
  }

  /// Always re-schedules notifications for all active tasks with reminders.
  /// Called after saving/deleting a task.
  Future<void> scheduleAll() async {
    final tasks = await _taskRepo.watchTasks().first;
    final active = tasks.where((t) => !t.archived && t.reminders.isNotEmpty).toList();
    await _notificationRepo.scheduleAllNotifications(active);
  }
}

class GetNotificationsEnabledUseCase {
  final NotificationRepository _repo;

  const GetNotificationsEnabledUseCase(this._repo);

  Future<bool> call() => _repo.getNotificationsEnabled();
}
