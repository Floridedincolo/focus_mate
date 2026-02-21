import '../../models/task.dart';
import '../../models/repeatTypes.dart';

/// Returns `true` when [task] is scheduled to occur on [date].
///
/// This is a pure function with no side-effects, making it straightforward
/// to unit-test without any Flutter or Firebase dependencies.
bool occursOn(Task task, DateTime date) {
  final targetDay = date.weekday;
  final isSameDay = date.year == task.startDate.year &&
      date.month == task.startDate.month &&
      date.day == task.startDate.day;

  if (task.oneTime) {
    return isSameDay;
  }

  switch (task.repeatType) {
    case RepeatType.daily:
      return !date.isBefore(task.startDate);
    case RepeatType.weekly:
      final difference = date.difference(task.startDate).inDays;
      return difference >= 0 && difference % 7 == 0;
    case RepeatType.custom:
      const weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return task.days[weekdays[targetDay - 1]] == true &&
          !date.isBefore(task.startDate);
    default:
      return false;
  }
}
