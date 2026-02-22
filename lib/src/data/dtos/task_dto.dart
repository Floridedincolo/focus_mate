import 'package:cloud_firestore/cloud_firestore.dart';

/// Data Transfer Object for Task - matches Firestore structure
class TaskDTO {
  final String id;
  final String title;
  final bool oneTime;
  final bool archived;
  final int streak;
  final DateTime startDate;
  final String? startTime; // "HH:mm"
  final String? endTime;   // "HH:mm"
  final String? repeatType; // "daily", "weekly", "custom"
  final List<Map<String, dynamic>> reminders;
  final Map<String, bool> days;

  TaskDTO({
    required this.id,
    required this.title,
    this.oneTime = false,
    this.archived = false,
    this.streak = 0,
    required this.startDate,
    this.startTime,
    this.endTime,
    this.repeatType,
    this.reminders = const [],
    this.days = const {},
  });

  /// Create from Firestore document
  factory TaskDTO.fromFirestore(Map<String, dynamic> data) {
    return TaskDTO(
      id: data['id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      oneTime: data['oneTime'] as bool? ?? true,
      archived: data['archived'] as bool? ?? false,
      streak: data['streak'] as int? ?? 0,
      startDate: data['startDate'] is Timestamp
          ? (data['startDate'] as Timestamp).toDate()
          : data['startDate'] is String
              ? DateTime.parse(data['startDate'] as String)
              : DateTime.now(),
      startTime: data['startTime'] as String?,
      endTime: data['endTime'] as String?,
      repeatType: data['repeatType'] as String?,
      reminders: (data['reminders'] as List<dynamic>?)
              ?.map((r) => Map<String, dynamic>.from(r as Map))
              .toList() ??
          [],
      days: (data['days'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value as bool),
          ) ??
          {},
    );
  }

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'oneTime': oneTime,
      'archived': archived,
      'streak': streak,
      'startDate': Timestamp.fromDate(startDate),
      'startTime': startTime,
      'endTime': endTime,
      'repeatType': repeatType,
      'reminders': reminders,
      'days': days,
    };
  }

  TaskDTO copyWith({
    String? id,
    String? title,
    bool? oneTime,
    bool? archived,
    int? streak,
    DateTime? startDate,
    String? startTime,
    String? endTime,
    String? repeatType,
    List<Map<String, dynamic>>? reminders,
    Map<String, bool>? days,
  }) {
    return TaskDTO(
      id: id ?? this.id,
      title: title ?? this.title,
      oneTime: oneTime ?? this.oneTime,
      archived: archived ?? this.archived,
      streak: streak ?? this.streak,
      startDate: startDate ?? this.startDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      repeatType: repeatType ?? this.repeatType,
      reminders: reminders ?? this.reminders,
      days: days ?? this.days,
    );
  }
}

/// Data Transfer Object for TaskStatus (completions subcollection)
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
      status: data['status'] as String? ?? 'upcoming',
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

