import '../repositories/notification_repository.dart';
import '../repositories/task_repository.dart';
import '../../presentation/widgets/alarm_debug_overlay.dart';

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
    AlarmDebugLog.log('UseCase.scheduleAll: fetching tasks...');
    final tasks = await _taskRepo.watchTasks().first;
    final active = tasks.where((t) => !t.archived && t.reminders.isNotEmpty).toList();
    AlarmDebugLog.log('UseCase.scheduleAll: ${tasks.length} total, ${active.length} with reminders');
    await _notificationRepo.scheduleAllNotifications(active);
    AlarmDebugLog.log('UseCase.scheduleAll: DONE');
  }
}

class GetNotificationsEnabledUseCase {
  final NotificationRepository _repo;

  const GetNotificationsEnabledUseCase(this._repo);

  Future<bool> call() => _repo.getNotificationsEnabled();
}
