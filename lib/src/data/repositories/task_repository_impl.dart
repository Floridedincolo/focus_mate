import '../../domain/repositories/task_repository.dart';
import '../../domain/entities/task.dart';
import '../datasources/task_data_source.dart';
import '../mappers/task_mapper.dart';

/// Concrete implementation of TaskRepository
class TaskRepositoryImpl implements TaskRepository {
  final RemoteTaskDataSource remoteDataSource;
  final LocalTaskDataSource localDataSource;

  TaskRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Stream<List<Task>> watchTasks() {
    return remoteDataSource.watchTasks().map((dtos) {
      localDataSource.saveTasks(dtos).ignore();
      return TaskMapper.toDomainList(dtos);
    });
  }

  @override
  Future<void> saveTask(Task task) async {
    final dto = TaskMapper.toDTO(task);
    await remoteDataSource.saveTask(dto);
    await localDataSource.saveTasks([dto]);
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await remoteDataSource.deleteTask(taskId);
  }

  @override
  Future<void> archiveTask(String taskId, bool archive) async {
    await remoteDataSource.archiveTask(taskId, archive);
  }

  @override
  Future<String> getCompletionStatus(Task task, DateTime date) {
    return remoteDataSource.getCompletionStatus(task.id, date);
  }

  @override
  Future<int> markTaskStatus(Task task, DateTime date, String status) {
    final dto = TaskMapper.toDTO(task);
    return remoteDataSource.markTaskStatus(dto, date, status);
  }

  @override
  Future<int> clearCompletion(Task task, DateTime date) {
    final dto = TaskMapper.toDTO(task);
    return remoteDataSource.clearCompletion(dto, date);
  }
}

