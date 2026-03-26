import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/task.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_service.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationService _service;
  static const _prefKey = 'notifications_enabled';

  /// Day-key to weekday number mapping (DateTime.monday == 1, etc.)
  static const _dayToWeekday = {
    'Mon': 1, 'Tue': 2, 'Wed': 3, 'Thu': 4, 'Fri': 5, 'Sat': 6, 'Sun': 7,
  };

  NotificationRepositoryImpl(this._service);

  @override
  Future<void> initialize() => _service.initialize();

  @override
  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? true;
  }

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
  }

  @override
  Future<void> scheduleAllNotifications(List<Task> tasks) async {
    await _service.cancelAll();

    int idCounter = 0;
    for (final task in tasks) {
      for (final reminder in task.reminders) {
        for (final entry in reminder.days.entries) {
          if (!entry.value) continue;
          final weekday = _dayToWeekday[entry.key];
          if (weekday == null) continue;

          await _service.scheduleWeeklyNotification(
            id: idCounter++,
            title: task.title,
            body: reminder.message.trim().isEmpty
                ? 'Time for: ${task.title}'
                : reminder.message,
            hour: reminder.time.hour,
            minute: reminder.time.minute,
            weekday: weekday,
          );
        }
      }
    }
  }

  @override
  Future<void> cancelAllNotifications() => _service.cancelAll();
}
