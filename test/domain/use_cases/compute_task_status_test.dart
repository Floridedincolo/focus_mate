import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mate/models/task.dart';
import 'package:focus_mate/models/repeatTypes.dart';
import 'package:focus_mate/domain/use_cases/compute_task_status.dart';

void main() {
  final baseDate = DateTime(2024, 6, 15); // a Saturday

  Task makeTask({TimeOfDay? startTime, TimeOfDay? endTime}) {
    return Task(
      id: 'test-id',
      title: 'Test Task',
      startDate: baseDate,
      repeatType: RepeatType.daily,
      startTime: startTime,
      endTime: endTime,
    );
  }

  group('computeTaskStatus', () {
    test('returns completed when storedStatus is completed', () {
      final task = makeTask();
      final result = computeTaskStatus(
        task: task,
        selectedDate: baseDate,
        storedStatus: 'completed',
        now: baseDate,
      );
      expect(result, 'completed');
    });

    test('returns missed for a past date with no stored completion', () {
      final task = makeTask();
      final yesterday = baseDate.subtract(const Duration(days: 1));
      final result = computeTaskStatus(
        task: task,
        selectedDate: yesterday,
        storedStatus: 'upcoming',
        now: baseDate,
      );
      expect(result, 'missed');
    });

    test('returns upcoming for a future date', () {
      final task = makeTask();
      final tomorrow = baseDate.add(const Duration(days: 1));
      final result = computeTaskStatus(
        task: task,
        selectedDate: tomorrow,
        storedStatus: 'upcoming',
        now: baseDate,
      );
      expect(result, 'upcoming');
    });

    test('returns upcoming for today when task end time has not passed', () {
      final task = makeTask(
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 11, minute: 0),
      );
      // now is before 11:00
      final now = DateTime(baseDate.year, baseDate.month, baseDate.day, 10, 0);
      final result = computeTaskStatus(
        task: task,
        selectedDate: baseDate,
        storedStatus: 'upcoming',
        now: now,
      );
      expect(result, 'upcoming');
    });

    test('returns missed for today when task end time has passed', () {
      final task = makeTask(
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 11, minute: 0),
      );
      // now is after 11:00
      final now = DateTime(baseDate.year, baseDate.month, baseDate.day, 12, 0);
      final result = computeTaskStatus(
        task: task,
        selectedDate: baseDate,
        storedStatus: 'upcoming',
        now: now,
      );
      expect(result, 'missed');
    });

    test('handles midnight-crossing task (end before start)', () {
      final task = makeTask(
        startTime: const TimeOfDay(hour: 23, minute: 0),
        endTime: const TimeOfDay(hour: 1, minute: 0),
      );
      // now is 23:30 – task hasn't ended yet (end is 01:00 next day)
      final now = DateTime(baseDate.year, baseDate.month, baseDate.day, 23, 30);
      final result = computeTaskStatus(
        task: task,
        selectedDate: baseDate,
        storedStatus: 'upcoming',
        now: now,
      );
      expect(result, 'upcoming');
    });

    test('returns upcoming for today with no end time', () {
      final task = makeTask(startTime: const TimeOfDay(hour: 9, minute: 0));
      final now = DateTime(baseDate.year, baseDate.month, baseDate.day, 8, 0);
      final result = computeTaskStatus(
        task: task,
        selectedDate: baseDate,
        storedStatus: 'upcoming',
        now: now,
      );
      expect(result, 'upcoming');
    });
  });
}
