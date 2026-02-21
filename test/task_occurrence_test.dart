import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mate/models/task.dart';
import 'package:focus_mate/models/repeatTypes.dart';
import 'package:focus_mate/domain/usecases/task_occurrence.dart';

void main() {
  group('occursOnTask', () {
    test('oneTime task occurs only on start date', () {
      final startDate = DateTime(2024, 2, 15);
      final task = Task(
        id: '1',
        title: 'One-time task',
        oneTime: true,
        startDate: startDate,
      );

      // Task occurs on start date
      expect(occursOnTask(task, startDate), isTrue);

      // Task does not occur on other dates
      expect(occursOnTask(task, startDate.add(const Duration(days: 1))), isFalse);
      expect(occursOnTask(task, startDate.subtract(const Duration(days: 1))), isFalse);
    });

    test('daily task occurs every day from start date onwards', () {
      final startDate = DateTime(2024, 2, 15);
      final task = Task(
        id: '2',
        title: 'Daily task',
        oneTime: false,
        startDate: startDate,
        repeatType: RepeatType.daily,
      );

      // Task occurs on start date
      expect(occursOnTask(task, startDate), isTrue);

      // Task occurs on future dates
      expect(occursOnTask(task, startDate.add(const Duration(days: 1))), isTrue);
      expect(occursOnTask(task, startDate.add(const Duration(days: 10))), isTrue);

      // Task does not occur before start date
      expect(occursOnTask(task, startDate.subtract(const Duration(days: 1))), isFalse);
    });

    test('weekly task occurs on same day of week every 7 days', () {
      // Start on Thursday, Feb 15, 2024
      final startDate = DateTime(2024, 2, 15);
      final task = Task(
        id: '3',
        title: 'Weekly task',
        oneTime: false,
        startDate: startDate,
        repeatType: RepeatType.weekly,
      );

      // Task occurs on start date (Thursday)
      expect(occursOnTask(task, startDate), isTrue);

      // Task occurs 7 days later (also Thursday)
      expect(occursOnTask(task, startDate.add(const Duration(days: 7))), isTrue);

      // Task occurs 14 days later (also Thursday)
      expect(occursOnTask(task, startDate.add(const Duration(days: 14))), isTrue);

      // Task does NOT occur 1 day later (Friday)
      expect(occursOnTask(task, startDate.add(const Duration(days: 1))), isFalse);

      // Task does NOT occur before start date
      expect(occursOnTask(task, startDate.subtract(const Duration(days: 1))), isFalse);
    });

    test('custom task occurs on specified weekdays from start date', () {
      final startDate = DateTime(2024, 2, 12); // Monday
      final task = Task(
        id: '4',
        title: 'Custom task',
        oneTime: false,
        startDate: startDate,
        repeatType: RepeatType.custom,
        days: {
          'Monday': true,
          'Wednesday': true,
          'Friday': true,
          'Tuesday': false,
          'Thursday': false,
          'Saturday': false,
          'Sunday': false,
        },
      );

      // Task occurs on Monday
      expect(occursOnTask(task, DateTime(2024, 2, 12)), isTrue); // Monday

      // Task occurs on Wednesday
      expect(occursOnTask(task, DateTime(2024, 2, 14)), isTrue); // Wednesday

      // Task occurs on Friday
      expect(occursOnTask(task, DateTime(2024, 2, 16)), isTrue); // Friday

      // Task does not occur on Tuesday
      expect(occursOnTask(task, DateTime(2024, 2, 13)), isFalse); // Tuesday

      // Task does not occur on Sunday
      expect(occursOnTask(task, DateTime(2024, 2, 18)), isFalse); // Sunday

      // Task does not occur before start date
      expect(occursOnTask(task, DateTime(2024, 2, 11)), isFalse);
    });

    test('custom task respects start date even if weekday matches', () {
      final startDate = DateTime(2024, 2, 15); // Thursday
      final task = Task(
        id: '5',
        title: 'Custom task with future start',
        oneTime: false,
        startDate: startDate,
        repeatType: RepeatType.custom,
        days: {
          'Monday': true,
          'Wednesday': true,
          'Friday': true,
          'Tuesday': false,
          'Thursday': false,
          'Saturday': false,
          'Sunday': false,
        },
      );

      // Monday before start date should return false even though Monday is in days
      expect(occursOnTask(task, DateTime(2024, 2, 12)), isFalse);

      // Friday on or after start date should return true
      expect(occursOnTask(task, DateTime(2024, 2, 16)), isTrue);
    });
  });
}

