import '../entities/task.dart';
import '../entities/repeat_type.dart';

/// Every accepted spelling for each weekday, indexed by [DateTime.weekday] - 1
/// (so index 0 = Monday … index 6 = Sunday).
///
/// Day maps reach us from several sources that historically used different
/// key formats: the schedule importer and [GenerateWeeklyTasksUseCase] write
/// 3-letter abbreviations ("Mon"), the add-task screen used to write full
/// names ("Monday"), and some Firestore documents store lowercase variants.
/// Matching tolerantly here keeps a single occurrence rule correct for all of
/// them, so the displayed schedule and the native lockdown enforcement never
/// disagree about which day a task runs on.
const _kWeekdayKeyVariants = <List<String>>[
  ['Mon', 'mon', 'Monday', 'monday'],
  ['Tue', 'tue', 'Tuesday', 'tuesday'],
  ['Wed', 'wed', 'Wednesday', 'wednesday'],
  ['Thu', 'thu', 'Thursday', 'thursday'],
  ['Fri', 'fri', 'Friday', 'friday'],
  ['Sat', 'sat', 'Saturday', 'saturday'],
  ['Sun', 'sun', 'Sunday', 'sunday'],
];

/// Whether [days] flags the given [weekday] (1 = Monday … 7 = Sunday) as true,
/// regardless of which key spelling was used to store it.
bool _daysFlagWeekday(Map<String, bool> days, int weekday) {
  for (final key in _kWeekdayKeyVariants[weekday - 1]) {
    if (days[key] == true) return true;
  }
  return false;
}

/// Pure function: determines whether [task] occurs on [date].
///
/// This is the single source of truth for occurrence, shared by the UI
/// (which decides what to show) and by the native sync (which decides when to
/// block / lock the device). Keeping both on this one function prevents a task
/// from being enforced on a day it isn't actually scheduled — e.g. a recurring
/// task firing before its [Task.startDate].
bool occursOnTask(Task task, DateTime date) {
  final dateOnly = DateTime(date.year, date.month, date.day);
  final startOnly = DateTime(
      task.startDate.year, task.startDate.month, task.startDate.day);

  if (task.oneTime) {
    return dateOnly == startOnly;
  }

  // A recurring task never occurs before its start date. This guard applies to
  // every repeat type, including daily — without it a "starts Thursday" task
  // would be treated as active today.
  if (dateOnly.isBefore(startOnly)) {
    return false;
  }

  switch (task.repeatType) {
    case RepeatType.daily:
      return true;
    case RepeatType.weekly:
    case RepeatType.custom:
      // Honour the flagged weekdays when any are set. If none are flagged
      // (empty / all-false map) fall back to occurring every day, matching the
      // lenient behaviour the native scheduler relied on.
      final hasSpecificDays = task.days.values.any((value) => value == true);
      if (!hasSpecificDays) return true;
      return _daysFlagWeekday(task.days, date.weekday);
    default:
      // Recurring task with an unknown/null repeat type → treat like daily.
      return true;
  }
}
