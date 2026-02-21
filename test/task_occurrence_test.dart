import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mate/domain/usecases/task_occurrence.dart';
import 'package:focus_mate/models/repeatTypes.dart';
import 'package:focus_mate/models/task.dart';

void main() {
  group('occursOnTask', () {
    final baseDate = DateTime(2024, 1, 1); // Monday

    test('oneTime task occurs only on its startDate', () {
      final task = Task(
        id: '1',
        title: 'One time task',
        oneTime: true,
        startDate: baseDate,
      );

      expect(occursOnTask(task, baseDate), isTrue);
      expect(occursOnTask(task, baseDate.add(const Duration(days: 1))), isFalse);
    });

    test('daily task occurs on and after startDate', () {
      final task = Task(
        id: '2',
        title: 'Daily task',
        oneTime: false,
        repeatType: RepeatType.daily,
        startDate: baseDate,
      );

      expect(occursOnTask(task, baseDate), isTrue);
      expect(occursOnTask(task, baseDate.add(const Duration(days: 5))), isTrue);
      expect(occursOnTask(task, baseDate.subtract(const Duration(days: 1))), isFalse);
    });

    test('weekly task occurs every 7 days from startDate', () {
      final task = Task(
        id: '3',
        title: 'Weekly task',
        oneTime: false,
        repeatType: RepeatType.weekly,
        startDate: baseDate,
      );

      expect(occursOnTask(task, baseDate), isTrue);
      expect(occursOnTask(task, baseDate.add(const Duration(days: 7))), isTrue);
      expect(occursOnTask(task, baseDate.add(const Duration(days: 14))), isTrue);
      expect(occursOnTask(task, baseDate.add(const Duration(days: 1))), isFalse);
      expect(occursOnTask(task, baseDate.add(const Duration(days: 6))), isFalse);
    });

    test('custom task occurs on specified weekdays on/after startDate', () {
      // baseDate is Monday (weekday 1)
      final task = Task(
        id: '4',
        title: 'Custom task',
        oneTime: false,
        repeatType: RepeatType.custom,
        startDate: baseDate,
        days: const {'Monday': true, 'Wednesday': true},
      );

      expect(occursOnTask(task, baseDate), isTrue); // Monday
      expect(occursOnTask(task, baseDate.add(const Duration(days: 2))), isTrue); // Wednesday
      expect(occursOnTask(task, baseDate.add(const Duration(days: 1))), isFalse); // Tuesday
      expect(occursOnTask(task, baseDate.subtract(const Duration(days: 7))), isFalse); // before startDate
    });

    test('task with null repeatType (not oneTime) returns false', () {
      final task = Task(
        id: '5',
        title: 'No repeat',
        oneTime: false,
        startDate: baseDate,
      );

      expect(occursOnTask(task, baseDate), isFalse);
    });
  });
}
