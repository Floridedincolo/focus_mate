/// Abstract contract for scheduling local notifications.
abstract class NotificationService {
  Future<void> initialize();

  Future<void> scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required int weekday, // 1=Monday..7=Sunday
  });

  Future<void> scheduleOneTimeNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required int hour,
    required int minute,
  });

  Future<void> cancelAll();
}
