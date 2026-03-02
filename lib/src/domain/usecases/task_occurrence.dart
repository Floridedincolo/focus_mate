import '../entities/task.dart';
import '../entities/repeat_type.dart';

/// 3-letter weekday abbreviations aligned with [DateTime.weekday]
/// (1 = Monday … 7 = Sunday). These must match the keys used by
/// [GenerateWeeklyTasksUseCase] when populating the `days` map.
const _kWeekdayAbbreviations = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Pure function: determines whether [task] occurs on [date].
/// This extracted logic can be unit tested easily and reused.
bool occursOnTask(Task task, DateTime date) {
  final isSameDay =
      date.year == task.startDate.year &&
      date.month == task.startDate.month &&
      date.day == task.startDate.day;

  if (task.oneTime) {
    return isSameDay;
  }

  // The date must not be before the task's start date.
  if (date.isBefore(task.startDate)) {
    return false;
  }

  // Abbreviation for the queried weekday (e.g. "Mon", "Wed").
  final dayAbbr = _kWeekdayAbbreviations[date.weekday - 1];

  switch (task.repeatType) {
    case RepeatType.daily:
      return true;
    case RepeatType.weekly:
      // Check the days map so that the task appears on every flagged
      // weekday, regardless of which date the schedule was imported on.
      return task.days[dayAbbr] == true;
    case RepeatType.custom:
      return task.days[dayAbbr] == true;
    default:
      return false;
  }
}

