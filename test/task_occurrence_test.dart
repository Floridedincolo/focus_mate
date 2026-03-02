import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mate/src/domain/entities/task.dart';
import 'package:focus_mate/src/domain/entities/repeat_type.dart';
import 'package:focus_mate/src/domain/usecases/task_occurrence.dart';

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

      expect(occursOnTask(task, startDate), isTrue);
      expect(
        occursOnTask(task, startDate.add(const Duration(days: 1))),
        isFalse,
      );
      expect(
        occursOnTask(task, startDate.subtract(const Duration(days: 1))),
        isFalse,
      );
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

      expect(occursOnTask(task, startDate), isTrue);
      expect(
        occursOnTask(task, startDate.add(const Duration(days: 1))),
        isTrue,
      );
      expect(
        occursOnTask(task, startDate.add(const Duration(days: 10))),
        isTrue,
      );
      expect(
        occursOnTask(task, startDate.subtract(const Duration(days: 1))),
        isFalse,
      );
    });

    test('weekly task occurs on flagged weekday from start date onwards', () {
      final startDate = DateTime(2024, 2, 15); // Thursday
      final task = Task(
        id: '3',
        title: 'Weekly task',
        oneTime: false,
        startDate: startDate,
        repeatType: RepeatType.weekly,
        days: {'Thu': true},
      );

      // On the start date (Thursday) – should match
      expect(occursOnTask(task, startDate), isTrue);
      // Next Thursday (7 days later)
      expect(
        occursOnTask(task, startDate.add(const Duration(days: 7))),
        isTrue,
      );
      // Two weeks later (Thursday)
      expect(
        occursOnTask(task, startDate.add(const Duration(days: 14))),
        isTrue,
      );
      // Friday – not flagged
      expect(
        occursOnTask(task, startDate.add(const Duration(days: 1))),
        isFalse,
      );
      // Before start date
      expect(
        occursOnTask(task, startDate.subtract(const Duration(days: 1))),
        isFalse,
      );
    });

    test('custom task occurs on specified weekdays from start date', () {
      final startDate = DateTime(2024, 2, 12); // Monday
      final task = Task(
        id: '4',
        title: 'MWF task',
        oneTime: false,
        startDate: startDate,
        repeatType: RepeatType.custom,
        days: {
          'Mon': true,
          'Tue': false,
          'Wed': true,
          'Thu': false,
          'Fri': true,
          'Sat': false,
          'Sun': false,
        },
      );

      // Monday (start date)
      expect(occursOnTask(task, DateTime(2024, 2, 12)), isTrue);
      // Wednesday
      expect(occursOnTask(task, DateTime(2024, 2, 14)), isTrue);
      // Friday
      expect(occursOnTask(task, DateTime(2024, 2, 16)), isTrue);
      // Tuesday - not selected
      expect(occursOnTask(task, DateTime(2024, 2, 13)), isFalse);
      // Before start date
      expect(occursOnTask(task, DateTime(2024, 2, 9)), isFalse);
    });
  });
}

