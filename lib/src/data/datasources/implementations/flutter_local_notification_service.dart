import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

import '../notification_service.dart';
import '../../../../main.dart' show navigatorKey;
import '../../../presentation/widgets/alarm_debug_overlay.dart';

class FlutterLocalNotificationService implements NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const _alarmSchedulerChannel = MethodChannel('com.example.focus_mate/alarm_scheduler');

  // NOTE: Canalele Android sunt imutabile după prima creare. Dacă trebuie
  // schimbate proprietăți (importance, sound, audio attributes, fullScreenIntent),
  // creștem versiunea ca să forțăm crearea unui canal nou.
  static const _alarmChannelId = 'task_alarms_v2';
  static const _alarmChannelName = 'Task Alarms';

  AndroidNotificationDetails _alarmDetails() => const AndroidNotificationDetails(
        _alarmChannelId,
        _alarmChannelName,
        channelDescription: 'Full-screen alarm reminders for tasks',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );

  /// Handle notification tap — if it's an alarm, navigate to the alarm screen.
  static void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if (data['type'] == 'alarm') {
        navigatorKey.currentState?.pushNamed('/alarm', arguments: data);
      }
    } catch (e) {
      debugPrint('[NOTIF] Error parsing notification payload: $e');
    }
  }

  AndroidNotificationDetails _reminderDetails() => const AndroidNotificationDetails(
        'task_reminders',
        'Task Reminders',
        channelDescription: 'Reminders for your scheduled tasks',
        importance: Importance.high,
        priority: Priority.high,
      );

  @override
  Future<void> initialize() async {
    AlarmDebugLog.log('NotifService.initialize() START');
    tz.initializeTimeZones();
    final timezoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneName));
    AlarmDebugLog.log('Timezone: $timezoneName');
    debugPrint('[NOTIF] Timezone: $timezoneName');

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // Request notification permission on Android 13+
    final notifGranted = await androidPlugin?.requestNotificationsPermission();
    AlarmDebugLog.log('Notif permission: $notifGranted');
    debugPrint('[NOTIF] Notification permission granted: $notifGranted');

    // Request exact alarm permission on Android 12+ if not already granted
    final canExact = await androidPlugin?.canScheduleExactNotifications();
    AlarmDebugLog.log('canScheduleExact: $canExact');
    debugPrint('[NOTIF] canScheduleExactNotifications: $canExact');
    if (canExact == false) {
      await androidPlugin?.requestExactAlarmsPermission();
    }

    // Request full-screen intent permission (Android 14+) for alarms
    await androidPlugin?.requestFullScreenIntentPermission();
    AlarmDebugLog.log('Permissions done, channel handler setup...');

    // Pre-create the alarm channel so its importance/sound are registered up front.
    // IMPORTANT: odată creat, canalul este imutabil — dacă schimbăm proprietăți
    // trebuie să bumpăm _alarmChannelId.
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _alarmChannelId,
        _alarmChannelName,
        description: 'Full-screen alarm reminders for tasks',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );

    // Handle cold-start: app was launched by tapping an alarm notification
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final response = launchDetails!.notificationResponse;
      if (response != null) {
        // Delay slightly so the navigator is ready after the widget tree builds
        Future.delayed(const Duration(milliseconds: 500), () {
          _onNotificationResponse(response);
        });
      }
    }

    // Listen for native alarm events (from AlarmReceiver → MainActivity)
    _alarmSchedulerChannel.setMethodCallHandler((call) async {
      AlarmDebugLog.log('MethodCall received: ${call.method}');
      if (call.method == 'alarmFired') {
        final data = Map<String, dynamic>.from(call.arguments as Map);
        AlarmDebugLog.log('ALARM FIRED! data=$data');
        debugPrint('[NOTIF] Native alarm fired: $data');
        final nav = navigatorKey.currentState;
        AlarmDebugLog.log('Navigator state: ${nav != null ? "OK" : "NULL"}');
        // Navigate to alarm screen
        Future.delayed(const Duration(milliseconds: 300), () {
          final nav2 = navigatorKey.currentState;
          AlarmDebugLog.log('Navigating to /alarm (nav=${nav2 != null ? "OK" : "NULL"})');
          nav2?.pushNamed('/alarm', arguments: data);
        });
      }
    });

    // Tell native side we're ready to receive alarm events (handles cold-start)
    AlarmDebugLog.log('Sending "ready" to native in 800ms...');
    Future.delayed(const Duration(milliseconds: 800), () {
      AlarmDebugLog.log('Sending "ready" to native NOW');
      _alarmSchedulerChannel.invokeMethod('ready');
    });
  }

  @override
  Future<void> scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required int weekday,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOfWeekday(weekday, hour, minute),
        NotificationDetails(
          android: _reminderDetails(),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.wallClockTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (e, st) {
      // Pe unele device-uri (MagicOS/MIUI, sau exact-alarms neacordat pe
      // Android 13+) planificarea poate eșua. Nu vrem să spargem save-ul
      // taskului — log-uim și mergem mai departe, consistent cu
      // scheduleOneTimeNotification.
      debugPrint('[NOTIF] ERROR scheduling weekly notification id=$id: $e');
      debugPrint('[NOTIF] Stack trace: $st');
    }
  }

  @override
  Future<void> scheduleOneTimeNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required int hour,
    required int minute,
  }) async {
    final scheduledTZ = tz.TZDateTime(
      tz.local,
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      hour,
      minute,
    );

    final now = tz.TZDateTime.now(tz.local);
    debugPrint('[NOTIF] scheduleOneTime: scheduledTZ=$scheduledTZ now=$now '
        'isBefore=${scheduledTZ.isBefore(now)}');

    // Don't schedule if the date is already in the past
    if (scheduledTZ.isBefore(now)) {
      debugPrint('[NOTIF] SKIPPED — scheduled time is in the past!');
      return;
    }

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTZ,
        NotificationDetails(
          android: _reminderDetails(),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.wallClockTime,
      );
      debugPrint('[NOTIF] zonedSchedule call succeeded for id=$id');

      final pending = await _plugin.pendingNotificationRequests();
      debugPrint('[NOTIF] Pending notifications after schedule: ${pending.length}');
      for (final p in pending) {
        debugPrint('[NOTIF]   pending: id=${p.id} title=${p.title}');
      }
    } catch (e, st) {
      debugPrint('[NOTIF] ERROR scheduling one-time notification: $e');
      debugPrint('[NOTIF] Stack trace: $st');
    }
  }

  @override
  Future<void> scheduleWeeklyAlarm({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required int weekday,
  }) async {
    try {
      final nextOccurrence = _nextInstanceOfWeekday(weekday, hour, minute);
      AlarmDebugLog.log('scheduleWeeklyAlarm id=$id wd=$weekday $hour:$minute epoch=${nextOccurrence.millisecondsSinceEpoch}');
      await _alarmSchedulerChannel.invokeMethod('scheduleNativeAlarm', {
        'id': id,
        'title': title,
        'body': body,
        'epochMs': nextOccurrence.millisecondsSinceEpoch,
        'isWeekly': true,
        'weekday': weekday,
        'hour': hour,
        'minute': minute,
      });
      AlarmDebugLog.log('scheduleWeeklyAlarm OK id=$id');
      debugPrint('[NOTIF] Scheduled weekly NATIVE ALARM id=$id weekday=$weekday $hour:$minute');
    } catch (e, st) {
      AlarmDebugLog.log('ERROR scheduleWeeklyAlarm id=$id: $e');
      debugPrint('[NOTIF] ERROR scheduling weekly alarm id=$id: $e');
      debugPrint('[NOTIF] Stack trace: $st');
    }
  }

  @override
  Future<void> scheduleOneTimeAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required int hour,
    required int minute,
  }) async {
    final scheduledTZ = tz.TZDateTime(
      tz.local,
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      hour,
      minute,
    );

    final now = tz.TZDateTime.now(tz.local);
    AlarmDebugLog.log('scheduleOneTimeAlarm: scheduled=$scheduledTZ now=$now');
    debugPrint('[NOTIF] scheduleOneTimeAlarm: scheduledTZ=$scheduledTZ now=$now');

    if (scheduledTZ.isBefore(now)) {
      AlarmDebugLog.log('SKIPPED — in the past!');
      debugPrint('[NOTIF] SKIPPED alarm — scheduled time is in the past!');
      return;
    }

    try {
      await _alarmSchedulerChannel.invokeMethod('scheduleNativeAlarm', {
        'id': id,
        'title': title,
        'body': body,
        'epochMs': scheduledTZ.millisecondsSinceEpoch,
        'isWeekly': false,
        'weekday': -1,
        'hour': hour,
        'minute': minute,
      });
      AlarmDebugLog.log('scheduleOneTimeAlarm OK id=$id epoch=${scheduledTZ.millisecondsSinceEpoch}');
      debugPrint('[NOTIF] Scheduled one-time NATIVE ALARM id=$id');
    } catch (e, st) {
      AlarmDebugLog.log('ERROR scheduleOneTimeAlarm id=$id: $e');
      debugPrint('[NOTIF] ERROR scheduling one-time alarm: $e');
      debugPrint('[NOTIF] Stack trace: $st');
    }
  }

  @override
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Returns the next [tz.TZDateTime] for the given weekday and time.
  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // Advance to the target weekday
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    // If it's already past, advance one week
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }

    return scheduled;
  }
}
