import 'package:focus_mate/models/task.dart';
import 'package:focus_mate/models/repeatTypes.dart';

/// Pure function: determines whether [task] occurs on [date].
/// This extracted logic can be unit tested easily and reused.
bool occursOnTask(Task task, DateTime date) {
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
      final weekdays = [
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
        "Sunday"
      ];
      return task.days[weekdays[targetDay - 1]] == true &&
          !date.isBefore(task.startDate);
    default:
      return false;
  }
}

