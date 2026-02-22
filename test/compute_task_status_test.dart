import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mate/src/domain/usecases/compute_task_status.dart';
import 'package:focus_mate/src/domain/repositories/task_repository.dart';
import 'package:focus_mate/src/domain/entities/task.dart';
import 'package:focus_mate/src/domain/entities/task_completion_status.dart';
import 'package:focus_mate/src/domain/entities/repeat_type.dart';

/// Fake implementation of TaskRepository for testing purposes.
class FakeTaskRepository implements TaskRepository {
  final Map<String, TaskCompletionStatus> _completionStatuses = {};

  /// Set a canned response for testing
  void setCompletionStatus(String taskId, DateTime date, TaskCompletionStatus status) {
    final key = '$taskId:${date.toIso8601String()}';
    _completionStatuses[key] = status;
  }

  @override
  Future<TaskCompletionStatus> getCompletionStatus(Task task, DateTime date) async {
    final key = '${task.id}:${date.toIso8601String()}';
    return _completionStatuses[key] ?? TaskCompletionStatus.upcoming;
  }

  @override
  Stream<List<Task>> watchTasks() => throw UnimplementedError();

  @override
  Future<void> saveTask(Task task) => throw UnimplementedError();

  @override
  Future<void> deleteTask(String taskId) => throw UnimplementedError();

  @override
  Future<void> archiveTask(String taskId, bool archive) =>
      throw UnimplementedError();

  @override
  Future<int> markTaskStatus(Task task, DateTime date, TaskCompletionStatus status) =>
      throw UnimplementedError();

  @override
  Future<int> clearCompletion(Task task, DateTime date) =>
      throw UnimplementedError();
}

void main() {
  group('computeTaskStatus', () {
    test(
      'returns hidden for task that does not occur on selected date',
      () async {
        final repo = FakeTaskRepository();
        final startDate = DateTime(2024, 2, 12); // Monday
        final task = Task(
          id: '1',
          title: 'Monday task',
          oneTime: false,
          startDate: startDate,
          repeatType: RepeatType.custom,
          days: {
            'Monday': true,
            'Tuesday': false,
            'Wednesday': false,
            'Thursday': false,
            'Friday': false,
            'Saturday': false,
            'Sunday': false,
          },
        );

        // Select Tuesday (when task does not occur)
        final status = await computeTaskStatus(
          task,
          DateTime(2024, 2, 13),
          repo,
        );

        expect(status, equals(TaskCompletionStatus.hidden));
      },
    );

    test('returns completed when task is marked completed', () async {
      final repo = FakeTaskRepository();
      final startDate = DateTime(2024, 2, 15);
      final selectedDate = DateTime(2024, 2, 15);
      final task = Task(
        id: '2',
        title: 'Daily task',
        oneTime: false,
        startDate: startDate,
        repeatType: RepeatType.daily,
      );

      // Set the repository to return 'completed' for this task
      repo.setCompletionStatus(task.id, selectedDate, TaskCompletionStatus.completed);

      final status = await computeTaskStatus(task, selectedDate, repo);

      expect(status, equals(TaskCompletionStatus.completed));
    });

    test('returns missed when task did not occur and is in the past', () async {
      final repo = FakeTaskRepository();
      final startDate = DateTime(2024, 1, 1);
      final selectedDate = DateTime(2024, 1, 15);
      final task = Task(
        id: '3',
        title: 'Daily task',
        oneTime: false,
        startDate: startDate,
        repeatType: RepeatType.daily,
      );

      // The repo will return 'upcoming' by default, but compute_task_status
      // delegates to the repo which checks date
      // For testing, let's set the repo to return 'missed'
      repo.setCompletionStatus(task.id, selectedDate, TaskCompletionStatus.missed);

      final status = await computeTaskStatus(task, selectedDate, repo);

      expect(status, equals(TaskCompletionStatus.missed));
    });

    test('returns upcoming for future task', () async {
      final repo = FakeTaskRepository();
      final startDate = DateTime(2025, 6, 1);
      final selectedDate = DateTime(2025, 6, 15);
      final task = Task(
        id: '4',
        title: 'Future daily task',
        oneTime: false,
        startDate: startDate,
        repeatType: RepeatType.daily,
      );

      final status = await computeTaskStatus(task, selectedDate, repo);

      expect(status, equals(TaskCompletionStatus.upcoming));
    });
  });
}

