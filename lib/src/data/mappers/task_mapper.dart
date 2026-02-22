import 'package:flutter/material.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_status.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/repeat_type.dart';
import '../dtos/task_dto.dart';

/// Mapper: TaskDTO <-> Task Entity
class TaskMapper {
  static Task toDomain(TaskDTO dto) {
    return Task(
      id: dto.id,
      title: dto.title,
      oneTime: dto.oneTime,
      archived: dto.archived,
      streak: dto.streak,
      startDate: dto.startDate,
      startTime: _parseTime(dto.startTime),
      endTime: _parseTime(dto.endTime),
      repeatType: _parseRepeatType(dto.repeatType),
      reminders: dto.reminders.map((r) => Reminder.fromMap(r)).toList(),
      days: dto.days,
    );
  }

  static TaskDTO toDTO(Task task) {
    return TaskDTO(
      id: task.id,
      title: task.title,
      oneTime: task.oneTime,
      archived: task.archived,
      streak: task.streak,
      startDate: task.startDate,
      startTime: _formatTime(task.startTime),
      endTime: _formatTime(task.endTime),
      repeatType: task.repeatType?.name,
      reminders: task.reminders.map((r) => r.toMap()).toList(),
      days: task.days,
    );
  }

  static List<Task> toDomainList(List<TaskDTO> dtos) {
    return dtos.map(toDomain).toList();
  }

  static List<TaskDTO> toDTOList(List<Task> tasks) {
    return tasks.map(toDTO).toList();
  }

  // --- Helper conversions ---

  static TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null) return null;
    final parts = timeStr.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  static String? _formatTime(TimeOfDay? time) {
    if (time == null) return null;
    return "${time.hour}:${time.minute}";
  }

  static RepeatType? _parseRepeatType(String? name) {
    if (name == null) return null;
    return RepeatType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => RepeatType.daily,
    );
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

