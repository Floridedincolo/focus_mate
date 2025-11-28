import 'package:focus_mate/models/task.dart';
import 'package:focus_mate/models/repeatTypes.dart';

extension TaskFilter on Task {
  bool occursOn(DateTime date) {
    final targetDay = date.weekday;
    final isSameDay = date.year == startDate.year &&
        date.month == startDate.month &&
        date.day == startDate.day;

    if (oneTime) {
      return isSameDay;
    }

    switch (repeatType) {
      case RepeatType.daily:
        return !date.isBefore(startDate);
      case RepeatType.weekly:
        final difference = date.difference(startDate).inDays;
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
        return days[weekdays[targetDay - 1]] == true &&
            !date.isBefore(startDate);
      default:
        return false;
    }
  }
}
