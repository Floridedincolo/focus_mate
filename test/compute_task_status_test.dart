import 'package:flutter_test/flutter_test.dart';
import 'package:focus_mate/domain/usecases/compute_task_status.dart';
import 'package:focus_mate/domain/repositories/task_repository.dart';
import 'package:focus_mate/models/task.dart';
import 'package:focus_mate/models/repeatTypes.dart';

/// Fake implementation of TaskRepository for testing purposes.
class FakeTaskRepository implements TaskRepository {
  final Map<String, String> _completionStatuses = {};

  /// Set a canned response for testing
  void setCompletionStatus(String taskId, DateTime date, String status) {
    final key = '$taskId:${date.toIso8601String()}';
    _completionStatuses[key] = status;
  }

  @override
  Future<String> getCompletionStatus(Task task, DateTime date) async {
    final key = '${task.id}:${date.toIso8601String()}';
    return _completionStatuses[key] ?? 'upcoming';
  }

  // These methods are not needed for compute_task_status testing
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
  Future<int> markTaskStatus(Task task, DateTime date, String status) =>
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

        expect(status, equals('hidden'));
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
      repo.setCompletionStatus(task.id, selectedDate, 'completed');

      final status = await computeTaskStatus(task, selectedDate, repo);

      expect(status, equals('completed'));
    });

    test('returns missed when task did not occur and is in the past', () async {
      final repo = FakeTaskRepository();
      final startDate = DateTime(2024, 2, 10);
      final selectedDate = DateTime(2024, 2, 15);
      final task = Task(
        id: '3',
        title: 'Daily task',
        oneTime: false,
        startDate: startDate,
        repeatType: RepeatType.daily,
      );

      // Repository returns 'missed' for a past date with no completion
      repo.setCompletionStatus(task.id, selectedDate, 'missed');

      final status = await computeTaskStatus(task, selectedDate, repo);

      expect(status, equals('missed'));
    });

    test('returns upcoming when task has no completion status', () async {
      final repo = FakeTaskRepository();
      final startDate = DateTime(2024, 2, 15);
      final selectedDate = DateTime(2024, 2, 15);
      final task = Task(
        id: '4',
        title: 'Daily task',
        oneTime: false,
        startDate: startDate,
        repeatType: RepeatType.daily,
      );

      // Repository will return 'upcoming' by default
      final status = await computeTaskStatus(task, selectedDate, repo);

      expect(status, equals('upcoming'));
    });
  });
}
