import 'package:flutter/material.dart';

import '../../models/task.dart';

/// Computes the display status of [task] for [selectedDate].
///
/// [storedStatus] is the value previously persisted in the repository
/// (e.g. `'completed'`, `'upcoming'`, or an empty string when absent).
/// [now] is the current wall-clock time, injected so the function remains
/// pure and trivially testable.
///
/// Returns one of: `'completed'`, `'missed'`, or `'upcoming'`.
String computeTaskStatus({
  required Task task,
  required DateTime selectedDate,
  required String storedStatus,
  required DateTime now,
}) {
  if (storedStatus == 'completed') return 'completed';

  final today = DateTime(now.year, now.month, now.day);
  final selected = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

  if (selected.isBefore(today)) return 'missed';
  if (selected.isAfter(today)) return 'upcoming';

  // selected == today
  if (task.endTime != null) {
    final endTime = task.endTime!;
    final startTime = task.startTime;
    // if end is before start the task crosses midnight – add one day
    final crossesMidnight = startTime != null &&
        (endTime.hour * 60 + endTime.minute) <
            (startTime.hour * 60 + startTime.minute);
    final taskEnd = DateTime(
      today.year,
      today.month,
      crossesMidnight ? today.day + 1 : today.day,
      endTime.hour,
      endTime.minute,
    );
    return now.isBefore(taskEnd) ? 'upcoming' : 'missed';
  }

  return 'upcoming';
}
