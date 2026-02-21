import 'dart:async';

import 'package:focus_mate/models/task.dart';

/// Repository interface for Task data operations.
/// Decouples the UI and domain logic from Firebase implementation details.
abstract class TaskRepository {
  /// Returns a stream of all tasks for the current user.
  Stream<List<Task>> watchTasks();

  /// Saves or updates a task.
  Future<void> saveTask(Task task);

  /// Deletes a task by ID.
  Future<void> deleteTask(String taskId);

  /// Archives or unarchives a task.
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

