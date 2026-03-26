import '../entities/task.dart';

abstract class NotificationRepository {
  Future<void> initialize();
  Future<void> scheduleAllNotifications(List<Task> tasks);
  Future<void> cancelAllNotifications();
  Future<bool> getNotificationsEnabled();
  Future<void> setNotificationsEnabled(bool enabled);
}
