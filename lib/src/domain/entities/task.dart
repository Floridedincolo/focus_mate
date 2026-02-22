import 'package:flutter/material.dart';
import 'reminder.dart';
import 'repeat_type.dart';

class Task {
  final String id;
  final String title;
  final bool oneTime;
  final bool archived;
  final DateTime startDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final RepeatType? repeatType;
  final Map<String, bool> days;
  final List<Reminder> reminders;
  int streak;

  Task({
    required this.id,
    required this.title,
    this.oneTime = false,
    this.archived = false,
    required this.startDate,
    this.startTime,
    this.endTime,
    this.repeatType,
    this.reminders = const [],
    this.days = const {},
    this.streak = 0,
  });

  Task copyWith({
    String? id,
    String? title,
    bool? oneTime,
    bool? archived,
    DateTime? startDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    RepeatType? repeatType,
    Map<String, bool>? days,
    List<Reminder>? reminders,
    int? streak,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      oneTime: oneTime ?? this.oneTime,
      archived: archived ?? this.archived,
      startDate: startDate ?? this.startDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      repeatType: repeatType ?? this.repeatType,
      days: days ?? this.days,
      reminders: reminders ?? this.reminders,
      streak: streak ?? this.streak,
    );
  }
}

