import '../entities/task.dart';

/// Task repository interface - abstracts data source
abstract class TaskRepository {
  /// Watch all tasks as a stream
  Stream<List<Task>> watchTasks();

  /// Save or update a task
  Future<void> saveTask(Task task);

  /// Delete a task
  Future<void> deleteTask(String taskId);

  /// Archive or unarchive a task
  Future<void> archiveTask(String taskId, bool archive);

  /// Returns the completion status for a task on a specific date.
  /// Can return: 'completed', 'missed', 'upcoming'.
  Future<String> getCompletionStatus(Task task, DateTime date);

  /// Marks a task as completed or updates its status for a date.
  /// Returns the updated streak count.
  Future<int> markTaskStatus(Task task, DateTime date, String status);

  /// Clears the completion record for a task on a date.
  /// Returns the updated streak count.
  Future<int> clearCompletion(Task task, DateTime date);
}

