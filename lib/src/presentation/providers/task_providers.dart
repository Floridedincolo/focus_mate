import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/task.dart';
import '../../domain/entities/task_completion_status.dart';
import '../../domain/entities/app_block_template.dart';
import '../../domain/usecases/task_usecases.dart';
import '../../domain/usecases/notification_usecases.dart';
import '../../core/service_locator.dart';
import 'friend_providers.dart';
import 'block_template_providers.dart';
import '../widgets/alarm_debug_overlay.dart';

final getTasksUseCaseProvider = Provider<GetTasksUseCase>((ref) => getIt<GetTasksUseCase>());
final saveTaskUseCaseProvider = Provider<SaveTaskUseCase>((ref) => getIt<SaveTaskUseCase>());
final deleteTaskUseCaseProvider = Provider<DeleteTaskUseCase>((ref) => getIt<DeleteTaskUseCase>());
final markTaskStatusUseCaseProvider = Provider<MarkTaskStatusUseCase>((ref) => getIt<MarkTaskStatusUseCase>());
final clearCompletionUseCaseProvider = Provider<ClearCompletionUseCase>((ref) => getIt<ClearCompletionUseCase>());

final tasksStreamProvider = StreamProvider<List<Task>>((ref) {
  ref.watch(currentUserUidProvider);
  final usecase = ref.watch(getTasksUseCaseProvider);
  return usecase();
});

Future<void> _refreshNotifications() async {
  AlarmDebugLog.log('_refreshNotifications called');
  try {
    final enabled = await getIt<GetNotificationsEnabledUseCase>()();
    AlarmDebugLog.log('notifications enabled=$enabled');
    if (enabled) {
      await getIt<ToggleNotificationsUseCase>().scheduleAll();
      AlarmDebugLog.log('scheduleAll() done');
    }
  } catch (e, st) {
    AlarmDebugLog.log('ERROR _refreshNotifications: $e');
    debugPrint('[task_providers] notification refresh failed (ignored): $e\n$st');
  }
}

final saveTaskProvider = FutureProvider.family<void, Task>((ref, task) async {
  final usecase = ref.watch(saveTaskUseCaseProvider);
  await usecase(task);
  ref.invalidate(tasksStreamProvider);
  await _refreshNotifications();
});

final deleteTaskProvider = FutureProvider.family<void, String>((ref, taskId) async {
  final usecase = ref.watch(deleteTaskUseCaseProvider);
  await usecase(taskId);
  ref.invalidate(tasksStreamProvider);
  await _refreshNotifications();
});

final markTaskStatusProvider = FutureProvider.family<int, (Task, DateTime, TaskCompletionStatus)>((ref, params) {
  final usecase = ref.watch(markTaskStatusUseCaseProvider);
  return usecase(params.$1, params.$2, params.$3);
});

final clearCompletionProvider = FutureProvider.family<int, (Task, DateTime)>((ref, params) {
  final usecase = ref.watch(clearCompletionUseCaseProvider);
  return usecase(params.$1, params.$2);
});

final _timeTickProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});

final currentActiveTaskProvider = Provider<Task?>((ref) {
  ref.watch(_timeTickProvider);
  final tasksAsync = ref.watch(tasksStreamProvider);
  return tasksAsync.maybeWhen(
    data: (tasks) {
      final now = DateTime.now();
      final nowMinutes = now.hour * 60 + now.minute;

      for (final task in tasks) {
        if (task.archived) continue;
        if (task.startTime == null || task.endTime == null) continue;

        // Folosim verificarea tolerantă pentru zile
        final occursToday = _taskOccursOnDate(task, now);
        debugPrint("🔍 DEBUG task: occursToday=$occursToday | startTime=${task.startTime} | endTime=${task.endTime} | archived=${task.archived}");
        if (!occursToday) continue;

        final startMinutes = task.startTime!.hour * 60 + task.startTime!.minute;
        final endMinutes = task.endTime!.hour * 60 + task.endTime!.minute;

        if (nowMinutes >= startMinutes && nowMinutes < endMinutes) {
          return task;
        }
      }
      return null;
    },
    orElse: () => null,
  );
});

// ─── LOGICĂ NOUĂ ȘI TOLERANTĂ PENTRU ZILELE SĂPTĂMÂNII ───

// Returnează TOATE variantele posibile în care o zi ar putea fi salvată în Firebase
List<String> _getPossibleDayKeys(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return ['monday', 'Mon', 'mon', 'Monday'];
    case DateTime.tuesday:
      return ['tuesday', 'Tue', 'tue', 'Tuesday'];
    case DateTime.wednesday:
      return ['wednesday', 'Wed', 'wed', 'Wednesday'];
    case DateTime.thursday:
      return ['thursday', 'Thu', 'thu', 'Thursday'];
    case DateTime.friday:
      return ['friday', 'Fri', 'fri', 'Friday'];
    case DateTime.saturday:
      return ['saturday', 'Sat', 'sat', 'Saturday'];
    case DateTime.sunday:
      return ['sunday', 'Sun', 'sun', 'Sunday'];
    default:
      return [];
  }
}

bool _taskOccursOnDate(Task task, DateTime date) {
  if (task.oneTime) {
    return task.startDate.year == date.year &&
        task.startDate.month == date.month &&
        task.startDate.day == date.day;
  }

  // Verificăm dacă există cel puțin o zi selectată ca fiind adevărată
  final hasSpecificDays = task.days.values.any((value) => value == true);

  if (hasSpecificDays) {
    // Obținem toate formatele posibile pentru ziua curentă (ex: Luni -> 'Mon', 'monday', etc)
    final possibleKeys = _getPossibleDayKeys(date.weekday);

    // Verificăm dacă ORICARE dintre aceste chei există și are valoarea true
    for (final key in possibleKeys) {
      if (task.days[key] == true) {
        return true;
      }
    }
    // Dacă am căutat prin toate variantele și nu am găsit niciun true, nu e programat azi
    return false;
  }

  // Dacă harta e goală SAU toate valorile sunt false (cazul Daily fallback)
  return true;
}

// ─── GENERATORUL DE ORAR SINCRONIZAT PE DISK ───

Future<void> syncFocusScheduleToNative(List<Task> tasks, List<AppBlockTemplate> templates) async {
  try {
    final now = DateTime.now();
    List<Map<String, dynamic>> schedule = [];

    for (int i = 0; i < 7; i++) {
      final targetDate = now.add(Duration(days: i));

      for (final task in tasks) {
        if (task.archived || task.startTime == null || task.endTime == null || task.blockTemplateId == null) continue;

        // Folosim noua funcție simplificată
        if (_taskOccursOnDate(task, targetDate)) {
          final template = templates.firstWhere(
                (t) => t.id == task.blockTemplateId,
            orElse: () => AppBlockTemplate(id: 'dummy', name: 'dummy', packages: []),
          );

          if (template.id == 'dummy') continue;

          final start = DateTime(targetDate.year, targetDate.month, targetDate.day, task.startTime!.hour, task.startTime!.minute);
          var end = DateTime(targetDate.year, targetDate.month, targetDate.day, task.endTime!.hour, task.endTime!.minute);

          if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
            end = end.add(const Duration(days: 1));
          }

          schedule.add({
            'startMs': start.millisecondsSinceEpoch,
            'endMs': end.millisecondsSinceEpoch,
            'taskName': task.title,
            'apps': template.packages,
            'isWhitelist': template.isWhitelist,
            'blockedWebsites': template.blockedWebsites,
            'blockedKeywords': template.blockedKeywords,
          });
        }
      }
    }

    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/schedule.json');

    await file.writeAsString(jsonEncode(schedule), flush: true);

    debugPrint('✅ ORAR ACTUALIZAT PE DISK: ${schedule.length} ferestre la ${file.path}');
  } catch (e) {
    debugPrint('❌ Eroare la sincronizarea orarului: $e');
  }
}