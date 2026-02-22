import '../../domain/repositories/task_repository.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_status.dart';
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
    // Stream from remote (Firestore) to get real-time updates
    return remoteDataSource.watchTasks().map((dtos) {
      // Also cache locally
      localDataSource.saveTasks(dtos).ignore();
      return TaskMapper.toDomainList(dtos);
    });
  }

  @override
  Future<Task?> getTask(String taskId) async {
    try {
      final dto = await remoteDataSource.getTask(taskId);
      if (dto == null) return null;
      return TaskMapper.toDomain(dto);
    } catch (e) {
      // Fallback to local cache
      final cached = await localDataSource.getTask(taskId);
      return cached != null ? TaskMapper.toDomain(cached) : null;
    }
  }

  @override
  Future<void> saveTask(Task task) async {
    final dto = TaskMapper.toDTO(task);
    await remoteDataSource.saveTask(dto);
    await localDataSource.saveTasks([dto]); // Cache it
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await remoteDataSource.deleteTask(taskId);
  }

  @override
  Future<TaskStatus?> getTaskStatus(String taskId, DateTime date) async {
    try {
      // Note: remoteDataSource returns TaskDTO, not TaskStatusDTO
      // This is a data source limitation - implement properly when needed
      final dto = await remoteDataSource.getTaskStatus(taskId, date);
      if (dto == null) return null;
      return null; // TODO: Implement proper TaskStatus retrieval
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> markTaskStatus(String taskId, DateTime date, String status) {
    return remoteDataSource.markTaskStatus(taskId, date, status);
  }

  @override
  Future<Map<String, int>> getCompletionStats(
    DateTime startDate,
    DateTime endDate,
  ) {
    return remoteDataSource.getCompletionStats(startDate, endDate);
  }
}

