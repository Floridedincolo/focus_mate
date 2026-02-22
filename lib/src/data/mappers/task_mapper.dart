import 'dart:convert' show base64;
import '../../domain/entities/task.dart';
import '../../domain/entities/task_status.dart';
import '../dtos/task_dto.dart';

/// Mapper: TaskDTO <-> Task Entity
class TaskMapper {
  static Task toDomain(TaskDTO dto) {
    return Task(
      id: dto.id,
      title: dto.title,
      description: dto.description,
      createdAt: dto.createdAt,
      dueDate: dto.dueDate,
      metadata: dto.metadata,
      isCompleted: dto.isCompleted,
    );
  }

  static TaskDTO toDTO(Task task) {
    return TaskDTO(
      id: task.id,
      title: task.title,
      description: task.description,
      createdAt: task.createdAt,
      dueDate: task.dueDate,
      metadata: task.metadata,
      isCompleted: task.isCompleted,
    );
  }

  static List<Task> toDomainList(List<TaskDTO> dtos) {
    return dtos.map(toDomain).toList();
  }

  static List<TaskDTO> toDTOList(List<Task> tasks) {
    return tasks.map(toDTO).toList();
  }
}

/// Mapper: TaskStatusDTO <-> TaskStatus Entity
class TaskStatusMapper {
  static TaskStatus toDomain(TaskStatusDTO dto) {
    return TaskStatus(
      taskId: dto.taskId,
      date: dto.date,
      status: dto.status,
    );
  }

  static TaskStatusDTO toDTO(TaskStatus status) {
    return TaskStatusDTO(
      taskId: status.taskId,
      date: status.date,
      status: status.status,
    );
  }
}

