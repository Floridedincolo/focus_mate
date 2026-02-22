import '../entities/task.dart';
import '../entities/task_status.dart';

/// Task repository interface - abstracts data source
abstract class TaskRepository {
  /// Watch all tasks as a stream
  Stream<List<Task>> watchTasks();

  /// Get a single task by ID
  Future<Task?> getTask(String taskId);

  /// Save or update a task
  Future<void> saveTask(Task task);

  /// Delete a task
  Future<void> deleteTask(String taskId);

  /// Get task status for a specific date
  Future<TaskStatus?> getTaskStatus(String taskId, DateTime date);

  /// Mark task status on a specific date
  Future<void> markTaskStatus(String taskId, DateTime date, String status);

  /// Get completion statistics for a date range
  Future<Map<String, int>> getCompletionStats(
    DateTime startDate,
    DateTime endDate,
  );
}

