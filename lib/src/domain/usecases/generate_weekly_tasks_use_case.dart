import 'package:flutter/material.dart';
import '../entities/extracted_class.dart';
import '../entities/task.dart';
import '../entities/repeat_type.dart';

/// Ordered list of all day abbreviations used throughout the app.
const _kAllDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Afternoon/evening window for placing homework sessions.
const _kHomeworkWindowStart = 15; // 15:00
const _kHomeworkWindowEnd = 22;   // 22:00

/// Generates repeating [Task]s from a confirmed weekly timetable.
///
/// For each [ExtractedClass]:
///   • Creates a class [Task] (repeating weekly on that day).
///
/// For each class where [ExtractedClass.needsHomework] is true:
///   • Finds free afternoon/evening slots across the week (respecting
///     both newly imported classes AND the user's existing tasks from
///     Firestore that are passed in via [existingTasks]).
///   • Distributes weekly homework hours into those free slots as one
///     or more repeating study tasks (each capped at 2 h to avoid
///     marathon sessions).
class GenerateWeeklyTasksUseCase {
  int _nextId = 0;
  String _newId() => '${DateTime.now().millisecondsSinceEpoch}_${_nextId++}';

  Future<List<Task>> call({
    required List<ExtractedClass> classes,
    required List<Task> existingTasks,
    required DateTime importDate,
  }) async {
    final List<Task> result = [];

    // 1. Generate class tasks
    for (final c in classes) {
      result.add(_buildClassTask(c, importDate));
    }

    // 2. Build a busy-slots map: day → list of (start, end) in minutes-since-midnight
    final busySlots = _buildBusySlots(classes, existingTasks);

    // 3. For each class that needs homework, schedule study tasks
    for (final c in classes.where((c) => c.needsHomework)) {
      final studyTasks = _scheduleHomework(
        subject: c.subject,
        totalMinutes: (c.homeworkHoursPerWeek * 60).round(),
        busySlots: busySlots,
        importDate: importDate,
        // Prefer days that are NOT the same as the class day (study after attending)
        classDay: c.day,
      );
      result.addAll(studyTasks);

      // Mark the homework slots as busy so subsequent subjects don't overlap
      for (final t in studyTasks) {
        final start = t.startTime;
        final end = t.endTime;
        if (start != null && end != null) {
          for (final day in _kAllDays) {
            if (t.days[day] == true) {
              busySlots.putIfAbsent(day, () => []);
              busySlots[day]!.add((
                _toMinutes(start),
                _toMinutes(end),
              ));
            }
          }
        }
      }
    }

    return result;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Task _buildClassTask(ExtractedClass c, DateTime importDate) {
    return Task(
      id: _newId(),
      title: c.subject,
      oneTime: false,
      startDate: importDate,
      startTime: c.startTime,
      endTime: c.endTime,
      repeatType: RepeatType.weekly,
      days: {for (final d in _kAllDays) d: d == c.day},
    );
  }

  /// Collects all occupied (start, end) minute-pairs per day from
  /// both newly imported classes and existing repeating tasks.
  Map<String, List<(int, int)>> _buildBusySlots(
    List<ExtractedClass> classes,
    List<Task> existingTasks,
  ) {
    final Map<String, List<(int, int)>> busy = {};

    // From imported classes
    for (final c in classes) {
      busy.putIfAbsent(c.day, () => []);
      busy[c.day]!.add((_toMinutes(c.startTime), _toMinutes(c.endTime)));
    }

    // From existing repeating tasks that have time slots
    for (final t in existingTasks) {
      if (t.oneTime) continue; // one-off tasks don't block weekly slots
      final start = t.startTime;
      final end = t.endTime;
      if (start == null || end == null) continue;
      for (final day in _kAllDays) {
        if (t.days[day] == true) {
          busy.putIfAbsent(day, () => []);
          busy[day]!.add((_toMinutes(start), _toMinutes(end)));
        }
      }
    }

    return busy;
  }

  /// Returns the list of free (start, end) minute windows on [day]
  /// within the afternoon/evening homework window.
  List<(int, int)> _freeWindowsOnDay(
    String day,
    Map<String, List<(int, int)>> busySlots,
  ) {
    final windowStart = _kHomeworkWindowStart * 60;
    final windowEnd = _kHomeworkWindowEnd * 60;

    // Collect and sort busy intervals that overlap our window
    final busy = (busySlots[day] ?? [])
        .where((s) => s.$2 > windowStart && s.$1 < windowEnd)
        .toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));

    // Walk the window and collect gaps
    final List<(int, int)> free = [];
    int cursor = windowStart;

    for (final slot in busy) {
      final slotStart = slot.$1.clamp(windowStart, windowEnd);
      final slotEnd = slot.$2.clamp(windowStart, windowEnd);
      if (slotStart > cursor) {
        free.add((cursor, slotStart));
      }
      cursor = slotEnd > cursor ? slotEnd : cursor;
    }

    if (cursor < windowEnd) {
      free.add((cursor, windowEnd));
    }

    return free;
  }

  List<Task> _scheduleHomework({
    required String subject,
    required int totalMinutes,
    required Map<String, List<(int, int)>> busySlots,
    required DateTime importDate,
    required String classDay,
  }) {
    // Max 120 min per session so we don't create a 6-hour block
    const maxSessionMinutes = 120;
    final List<Task> tasks = [];

    // Build a ranked list of candidate days (prefer days after the class day,
    // but include all days to guarantee we can always find slots)
    final classIndex = _kAllDays.indexOf(classDay);
    final orderedDays = [
      ..._kAllDays.sublist(classIndex + 1),
      ..._kAllDays.sublist(0, classIndex + 1),
    ];

    int remaining = totalMinutes;

    for (final day in orderedDays) {
      if (remaining <= 0) break;

      final windows = _freeWindowsOnDay(day, busySlots);
      for (final window in windows) {
        if (remaining <= 0) break;

        final available = window.$2 - window.$1;
        if (available < 30) continue; // skip windows shorter than 30 min

        final sessionMinutes = remaining.clamp(30, available.clamp(30, maxSessionMinutes));
        final startMin = window.$1;
        final endMin = startMin + sessionMinutes;

        final startTime = TimeOfDay(hour: startMin ~/ 60, minute: startMin % 60);
        final endTime = TimeOfDay(hour: endMin ~/ 60, minute: endMin % 60);

        tasks.add(Task(
          id: _newId(),
          title: 'Study: $subject',
          oneTime: false,
          startDate: importDate,
          startTime: startTime,
          endTime: endTime,
          repeatType: RepeatType.weekly,
          days: {for (final d in _kAllDays) d: d == day},
        ));

        remaining -= sessionMinutes;

        // Mark this window as now busy for subsequent subjects
        busySlots.putIfAbsent(day, () => []);
        busySlots[day]!.add((startMin, endMin));
        break; // one session per day is enough
      }
    }

    return tasks;
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;
}

