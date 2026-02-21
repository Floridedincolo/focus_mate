import '../../models/task.dart';

abstract class TaskRepository {
  Stream<List<Task>> watchTasks();
  Future<void> saveTask(Task task);
  Future<void> deleteTask(String taskId);
  Future<int> markTaskStatus(Task task, DateTime date, String status);
  Future<int> clearCompletion(Task task, DateTime date);
  Future<String> getCompletionStatus(Task task, DateTime date);
}
