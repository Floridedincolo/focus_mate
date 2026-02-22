/// Task entity - pure business domain
class Task {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime? dueDate;
  final Map<String, dynamic> metadata;
  final bool isCompleted;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    this.dueDate,
    this.metadata = const {},
    this.isCompleted = false,
  });

  /// Create a copy with modified fields
  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? dueDate,
    Map<String, dynamic>? metadata,
    bool? isCompleted,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      metadata: metadata ?? this.metadata,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  String toString() => 'Task(id: $id, title: $title, isCompleted: $isCompleted)';
}

