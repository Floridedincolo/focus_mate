import 'dart:convert';

/// Data Transfer Object for Task - matches Firestore structure
class TaskDTO {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime? dueDate;
  final Map<String, dynamic> metadata;
  final bool isCompleted;

  TaskDTO({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    this.dueDate,
    this.metadata = const {},
    this.isCompleted = false,
  });

  /// Create from Firestore document
  factory TaskDTO.fromFirestore(Map<String, dynamic> data) {
    return TaskDTO(
      id: data['id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      createdAt: (data['createdAt'] != null)
          ? DateTime.parse(data['createdAt'] as String)
          : DateTime.now(),
      dueDate: (data['dueDate'] != null)
          ? DateTime.parse(data['dueDate'] as String)
          : null,
      metadata: (data['metadata'] as Map<String, dynamic>?) ?? {},
      isCompleted: data['isCompleted'] as bool? ?? false,
    );
  }

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'metadata': metadata,
      'isCompleted': isCompleted,
    };
  }

  /// Create a copy with modified fields
  TaskDTO copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? dueDate,
    Map<String, dynamic>? metadata,
    bool? isCompleted,
  }) {
    return TaskDTO(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      metadata: metadata ?? this.metadata,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// Data Transfer Object for TaskStatus
class TaskStatusDTO {
  final String taskId;
  final DateTime date;
  final String status;

  TaskStatusDTO({
    required this.taskId,
    required this.date,
    required this.status,
  });

  factory TaskStatusDTO.fromFirestore(Map<String, dynamic> data) {
    return TaskStatusDTO(
      taskId: data['taskId'] as String? ?? '',
      date: (data['date'] != null)
          ? DateTime.parse(data['date'] as String)
          : DateTime.now(),
      status: data['status'] as String? ?? 'pending',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'taskId': taskId,
      'date': date.toIso8601String(),
      'status': status,
    };
  }
}

