/// Represents the status of a task on a specific date
class TaskStatus {
  final String taskId;
  final DateTime date;
  final String status; // 'completed', 'pending', 'skipped', etc.

  TaskStatus({
    required this.taskId,
    required this.date,
    required this.status,
  });

  TaskStatus copyWith({
    String? taskId,
    DateTime? date,
    String? status,
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

