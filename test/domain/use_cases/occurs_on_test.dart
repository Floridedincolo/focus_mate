import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mate/models/task.dart';
import 'package:focus_mate/models/repeatTypes.dart';
import 'package:focus_mate/domain/use_cases/occurs_on.dart';

void main() {
  group('occursOn', () {
    final baseDate = DateTime(2024, 1, 1); // Monday

    Task makeTask({
      bool oneTime = false,
      RepeatType? repeatType,
      Map<String, bool> days = const {},
    }) {
      return Task(
        id: 'test-id',
        title: 'Test Task',
        oneTime: oneTime,
        startDate: baseDate,
        repeatType: repeatType,
        days: days,
      );
    }

    test('one-time task occurs only on its start date', () {
      final task = makeTask(oneTime: true);
      expect(occursOn(task, baseDate), isTrue);
      expect(occursOn(task, baseDate.add(const Duration(days: 1))), isFalse);
      expect(occursOn(task, baseDate.subtract(const Duration(days: 1))), isFalse);
    });

    test('daily task occurs on and after start date', () {
      final task = makeTask(repeatType: RepeatType.daily);
      expect(occursOn(task, baseDate), isTrue);
      expect(occursOn(task, baseDate.add(const Duration(days: 5))), isTrue);
      expect(occursOn(task, baseDate.subtract(const Duration(days: 1))), isFalse);
    });

    test('weekly task occurs every 7 days from start date', () {
      final task = makeTask(repeatType: RepeatType.weekly);
      expect(occursOn(task, baseDate), isTrue);
      expect(occursOn(task, baseDate.add(const Duration(days: 7))), isTrue);
      expect(occursOn(task, baseDate.add(const Duration(days: 14))), isTrue);
      expect(occursOn(task, baseDate.add(const Duration(days: 1))), isFalse);
      expect(occursOn(task, baseDate.add(const Duration(days: 6))), isFalse);
    });

    test('custom task occurs on selected weekdays on or after start date', () {
      // baseDate is Monday (weekday == 1)
      final task = makeTask(
        repeatType: RepeatType.custom,
        days: const {'Monday': true, 'Wednesday': true},
      );
      // Monday after start
      expect(occursOn(task, baseDate.add(const Duration(days: 7))), isTrue);
      // Wednesday after start
      expect(
        occursOn(task, baseDate.add(const Duration(days: 2))), // Wednesday
        isTrue,
      );
      // Tuesday – not selected
      expect(occursOn(task, baseDate.add(const Duration(days: 1))), isFalse);
      // Before start date
      expect(occursOn(task, baseDate.subtract(const Duration(days: 7))), isFalse);
    });

    test('returns false when repeatType is null for non-one-time task', () {
      final task = makeTask();
      expect(occursOn(task, baseDate), isFalse);
    });
  });
}
