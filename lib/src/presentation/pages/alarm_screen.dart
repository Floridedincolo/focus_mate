import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with SingleTickerProviderStateMixin {
  static const _alarmChannel = MethodChannel('com.example.focus_mate/alarm');
  static const _alarmSchedulerChannel = MethodChannel('com.example.focus_mate/alarm_scheduler');

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  Map<String, dynamic> _payload = {};

  bool _soundStarted = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _payload = args;
    } else if (args is String) {
      try {
        _payload = jsonDecode(args) as Map<String, dynamic>;
      } catch (_) {
        _payload = {'title': args};
      }
    }
    // Only play alarm sound via method channel if NOT launched from native
    // foreground service (which already plays its own sound).
    // Native alarms have 'isWeekly' key; notification-tap alarms don't.
    if (!_soundStarted && !_payload.containsKey('isWeekly')) {
      _soundStarted = true;
      _alarmChannel.invokeMethod('playAlarm');
    }
  }

  Future<void> _dismiss() async {
    await _alarmChannel.invokeMethod('stopAlarm');

    // Cancel the fallback notification
    final id = _payload['id'];
    if (id != null) {
      await FlutterLocalNotificationsPlugin().cancel(id as int);
      // Also cancel via native (clears the native fallback notification)
      try {
        await _alarmSchedulerChannel.invokeMethod('cancelNativeAlarm', {'id': id});
      } catch (_) {}
    }

    // Re-schedule if this was a weekly alarm
    final isWeekly = _payload['isWeekly'] == true;
    if (isWeekly && id != null) {
      final weekday = _payload['weekday'] as int? ?? -1;
      final hour = _payload['hour'] as int? ?? -1;
      final minute = _payload['minute'] as int? ?? -1;
      if (weekday > 0 && hour >= 0 && minute >= 0) {
        final title = _payload['title'] as String? ?? 'Alarm';
        final body = _payload['body'] as String? ?? '';
        // Compute next occurrence (7 days from now at same time)
        final now = DateTime.now();
        var next = DateTime(now.year, now.month, now.day, hour, minute);
        // Advance to matching weekday
        while (next.weekday != weekday || next.isBefore(now.add(const Duration(minutes: 1)))) {
          next = next.add(const Duration(days: 1));
        }
        try {
          await _alarmSchedulerChannel.invokeMethod('scheduleNativeAlarm', {
            'id': id,
            'title': title,
            'body': body,
            'epochMs': next.millisecondsSinceEpoch,
            'isWeekly': true,
            'weekday': weekday,
            'hour': hour,
            'minute': minute,
          });
          debugPrint('[ALARM] Re-scheduled weekly alarm id=$id for $next');
        } catch (e) {
          debugPrint('[ALARM] Failed to re-schedule weekly alarm: $e');
        }
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _alarmChannel.invokeMethod('stopAlarm');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskTitle = _payload['title'] as String? ?? 'Alarm';
    final taskBody = _payload['body'] as String? ?? '';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Pulsing alarm icon
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent.withValues(alpha: 0.15),
                  ),
                  child: const Icon(
                    Icons.alarm,
                    size: 64,
                    color: Colors.blueAccent,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Task title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  taskTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              if (taskBody.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    taskBody,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Text(
                TimeOfDay.now().format(context),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 48,
                  fontWeight: FontWeight.w200,
                ),
              ),

              const Spacer(flex: 3),

              // Dismiss button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _dismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 8,
                    ),
                    child: const Text(
                      'Dismiss',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
