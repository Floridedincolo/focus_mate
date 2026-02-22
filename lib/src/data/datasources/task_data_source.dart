import '../dtos/task_dto.dart';

/// Remote data source for tasks (Firestore)
abstract class RemoteTaskDataSource {
  /// Watch all tasks from remote
  Stream<List<TaskDTO>> watchTasks();

  /// Save a task to remote
  Future<void> saveTask(TaskDTO task);

  /// Delete a task from remote
  Future<void> deleteTask(String taskId);

  /// Archive or unarchive a task
  Future<void> archiveTask(String taskId, bool archive);

  /// Get completion status for a task on a specific date
  Future<String> getCompletionStatus(String taskId, DateTime date);

  /// Mark task status on a date; returns updated streak
  Future<int> markTaskStatus(TaskDTO task, DateTime date, String status);

  /// Clear completion for a task on a date; returns updated streak
  Future<int> clearCompletion(TaskDTO task, DateTime date);
}

/// Local data source for tasks (cached)
abstract class LocalTaskDataSource {
  /// Get cached tasks
  Future<List<TaskDTO>> getTasks();

  /// Save tasks to cache
  Future<void> saveTasks(List<TaskDTO> tasks);

  /// Get single cached task
  Future<TaskDTO?> getTask(String taskId);

  /// Clear cache
  Future<void> clearCache();
}

