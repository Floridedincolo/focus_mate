import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/reminder.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_service.dart';
import '../../presentation/widgets/alarm_debug_overlay.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationService _service;
  static const _prefKey = 'notifications_enabled';

  /// Day-key to weekday number mapping (DateTime.monday == 1, etc.)
  /// Accepts both short ('Mon') and long ('Monday') formats, case-insensitive.
  static int? _dayToWeekday(String day) {
    const map = {
      'mon': 1, 'monday': 1,
      'tue': 2, 'tuesday': 2,
      'wed': 3, 'wednesday': 3,
      'thu': 4, 'thursday': 4,
      'fri': 5, 'friday': 5,
      'sat': 6, 'saturday': 6,
      'sun': 7, 'sunday': 7,
    };
    return map[day.toLowerCase()];
  }

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
    try {
      await _service.cancelAll();
    } catch (e) {
      AlarmDebugLog.log('cancelAll failed (continuing): $e');
      debugPrint('[NOTIF] cancelAll failed (continuing): $e');
    }

    AlarmDebugLog.log('scheduleAll called, ${tasks.length} tasks');
    debugPrint('[NOTIF] scheduleAllNotifications called with ${tasks.length} tasks');

    int idCounter = 0;
    for (final task in tasks) {
      AlarmDebugLog.log('Task "${task.title}" oneTime=${task.oneTime} reminders=${task.reminders.length}');
      debugPrint('[NOTIF] Task "${task.title}" oneTime=${task.oneTime} '
          'startDate=${task.startDate} reminders=${task.reminders.length}');

      for (final reminder in task.reminders) {
        AlarmDebugLog.log('  Reminder ${reminder.time.hour}:${reminder.time.minute} type=${reminder.type} days=${reminder.days}');
        debugPrint('[NOTIF]   Reminder time=${reminder.time.hour}:${reminder.time.minute} '
            'days=${reminder.days}');

        final body = reminder.message.trim().isEmpty
            ? 'Time for: ${task.title}'
            : reminder.message;

        final isAlarm = reminder.type == ReminderType.alarm;
        AlarmDebugLog.log('  isAlarm=$isAlarm');

        if (task.oneTime) {
          debugPrint('[NOTIF]   -> Scheduling ONE-TIME ${isAlarm ? "ALARM" : "NOTIF"} '
              'for ${task.startDate} at ${reminder.time.hour}:${reminder.time.minute}');
          if (isAlarm) {
            await _service.scheduleOneTimeAlarm(
              id: idCounter++,
              title: task.title,
              body: body,
              scheduledDate: task.startDate,
              hour: reminder.time.hour,
              minute: reminder.time.minute,
            );
          } else {
            await _service.scheduleOneTimeNotification(
              id: idCounter++,
              title: task.title,
              body: body,
              scheduledDate: task.startDate,
              hour: reminder.time.hour,
              minute: reminder.time.minute,
            );
          }
        } else {
          // Recurring task: schedule weekly for each active day
          for (final entry in reminder.days.entries) {
            if (!entry.value) continue;
            final weekday = _dayToWeekday(entry.key);
            if (weekday == null) continue;

            if (isAlarm) {
              await _service.scheduleWeeklyAlarm(
                id: idCounter++,
                title: task.title,
                body: body,
                hour: reminder.time.hour,
                minute: reminder.time.minute,
                weekday: weekday,
              );
            } else {
              await _service.scheduleWeeklyNotification(
                id: idCounter++,
                title: task.title,
                body: body,
                hour: reminder.time.hour,
                minute: reminder.time.minute,
                weekday: weekday,
              );
            }
          }
        }
      }
    }
  }

  @override
  Future<void> cancelAllNotifications() => _service.cancelAll();
}
