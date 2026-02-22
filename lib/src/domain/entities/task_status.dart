import 'task_completion_status.dart';

/// Represents the status of a task on a specific date
class TaskStatus {
  final String taskId;
  final DateTime date;
  final TaskCompletionStatus status;

  TaskStatus({
    required this.taskId,
    required this.date,
    required this.status,
  });

  TaskStatus copyWith({
    String? taskId,
    DateTime? date,
    TaskCompletionStatus? status,
  }) {
    return TaskStatus(
      taskId: taskId ?? this.taskId,
      date: date ?? this.date,
      status: status ?? this.status,
    );
  }

  @override
  String toString() =>
      'TaskStatus(taskId: $taskId, date: $date, status: $status)';
}

