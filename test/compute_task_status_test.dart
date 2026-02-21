import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mate/domain/repositories/task_repository.dart';
import 'package:focus_mate/domain/usecases/compute_task_status.dart';
import 'package:focus_mate/models/repeatTypes.dart';
import 'package:focus_mate/models/task.dart';

class FakeRepo implements TaskRepository {
  final Map<String, String> _completions;

  FakeRepo(this._completions);

  @override
  Future<String> getCompletionStatus(Task task, DateTime date) async {
    final key = '${task.id}_${date.toIso8601String()}';
    return _completions[key] ?? 'upcoming';
  }

  @override
  Stream<List<Task>> watchTasks() => throw UnimplementedError();

  @override
  Future<void> saveTask(Task task) => throw UnimplementedError();

  @override
  Future<void> deleteTask(String taskId) => throw UnimplementedError();

  @override
  Future<int> markTaskStatus(Task task, DateTime date, String status) =>
      throw UnimplementedError();

  @override
  Future<int> clearCompletion(Task task, DateTime date) =>
      throw UnimplementedError();
}

void main() {
  final baseDate = DateTime(2024, 1, 1); // a fixed past date (Monday)

  Task _dailyTask() => Task(
        id: 'task1',
        title: 'Daily',
        oneTime: false,
        repeatType: RepeatType.daily,
        startDate: baseDate,
      );

  group('computeTaskStatus', () {
    test('returns hidden when task does not occur on selected date', () async {
      final task = Task(
        id: 'task2',
        title: 'One time',
        oneTime: true,
        startDate: baseDate,
      );
      final other = baseDate.add(const Duration(days: 1));
      final repo = FakeRepo({});

      final status = await computeTaskStatus(task, other, repo);
      expect(status, 'hidden');
    });

    test('returns completed when stored status is completed', () async {
      final task = _dailyTask();
      final date = baseDate;
      final key = '${task.id}_${date.toIso8601String()}';
      final repo = FakeRepo({key: 'completed'});

      final status = await computeTaskStatus(task, date, repo);
      expect(status, 'completed');
    });

    test('returns missed for a past date without stored completion', () async {
      final task = _dailyTask();
      // baseDate is in the past relative to now (2024-01-01)
      final repo = FakeRepo({});

      final status = await computeTaskStatus(task, baseDate, repo);
      expect(status, 'missed');
    });

    test('returns upcoming for a future date', () async {
      final task = _dailyTask();
      final future = DateTime.now().add(const Duration(days: 30));
      final repo = FakeRepo({});

      final status = await computeTaskStatus(task, future, repo);
      expect(status, 'upcoming');
    });
  });
}
