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
  final int streak;

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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Task &&
        other.id == id &&
        other.title == title &&
        other.oneTime == oneTime &&
        other.archived == archived &&
        other.startDate == startDate &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.repeatType == repeatType &&
        _mapsEqual(other.days, days) &&
        _listsEqual(other.reminders, reminders) &&
        other.streak == streak;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        oneTime,
        archived,
        startDate,
        startTime,
        endTime,
        repeatType,
        Object.hashAll(days.entries),
        Object.hashAll(reminders),
        streak,
      );

  static bool _mapsEqual(Map<String, bool> a, Map<String, bool> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  static bool _listsEqual(List<Reminder> a, List<Reminder> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

