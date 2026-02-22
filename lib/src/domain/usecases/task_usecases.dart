import '../repositories/task_repository.dart';
import '../entities/task.dart';

/// Use case: Get all tasks
class GetTasksUseCase {
  final TaskRepository _repository;

  GetTasksUseCase(this._repository);

  Stream<List<Task>> call() {
    return _repository.watchTasks();
  }
}

/// Use case: Create or update a task
class SaveTaskUseCase {
  final TaskRepository _repository;

  SaveTaskUseCase(this._repository);

  Future<void> call(Task task) {
    return _repository.saveTask(task);
  }
}

/// Use case: Delete a task
class DeleteTaskUseCase {
  final TaskRepository _repository;

  DeleteTaskUseCase(this._repository);

  Future<void> call(String taskId) {
    return _repository.deleteTask(taskId);
  }
}

/// Use case: Mark task as complete/pending on a specific date
class MarkTaskStatusUseCase {
  final TaskRepository _repository;

  MarkTaskStatusUseCase(this._repository);

  Future<void> call(String taskId, DateTime date, String status) {
    return _repository.markTaskStatus(taskId, date, status);
  }
}

/// Use case: Get task completion statistics
class GetCompletionStatsUseCase {
  final TaskRepository _repository;

  GetCompletionStatsUseCase(this._repository);

  Future<Map<String, int>> call(DateTime startDate, DateTime endDate) {
    return _repository.getCompletionStats(startDate, endDate);
  }
}

