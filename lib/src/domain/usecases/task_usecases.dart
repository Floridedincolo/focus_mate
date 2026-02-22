import '../repositories/task_repository.dart';
import '../entities/task.dart';
import '../entities/task_completion_status.dart';

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

/// Use case: Archive or unarchive a task
class ArchiveTaskUseCase {
  final TaskRepository _repository;

  ArchiveTaskUseCase(this._repository);

  Future<void> call(String taskId, bool archive) {
    return _repository.archiveTask(taskId, archive);
  }
}

/// Use case: Get task completion status for a specific date
class GetCompletionStatusUseCase {
  final TaskRepository _repository;

  GetCompletionStatusUseCase(this._repository);

  Future<TaskCompletionStatus> call(Task task, DateTime date) {
    return _repository.getCompletionStatus(task, date);
  }
}

/// Use case: Mark task status on a specific date; returns updated streak
class MarkTaskStatusUseCase {
  final TaskRepository _repository;

  MarkTaskStatusUseCase(this._repository);

  Future<int> call(Task task, DateTime date, TaskCompletionStatus status) {
    return _repository.markTaskStatus(task, date, status);
  }
}

/// Use case: Clear completion for a task on a date; returns updated streak
class ClearCompletionUseCase {
  final TaskRepository _repository;

  ClearCompletionUseCase(this._repository);

  Future<int> call(Task task, DateTime date) {
    return _repository.clearCompletion(task, date);
  }
}

