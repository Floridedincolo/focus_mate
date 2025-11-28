import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:focus_mate/models/reminder.dart';
import 'package:focus_mate/models/repeatTypes.dart';

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

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'oneTime': oneTime,
      'archived': archived,
      'streak': streak,
      'startDate': Timestamp.fromDate(startDate),
      'startTime': startTime != null ? "${startTime!.hour}:${startTime!.minute}" : null,
      'endTime': endTime != null ? "${endTime!.hour}:${endTime!.minute}" : null,
      'repeatType': repeatType?.name ?? RepeatType.daily.name,
      'reminders': reminders.map((r) => r.toMap()).toList(),
      'days': days,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      oneTime: map['oneTime'] ?? true,
      archived: map['archived'] ?? false,
      startDate: map['startDate'] is Timestamp
          ? (map['startDate'] as Timestamp).toDate()
          : DateTime.parse(map['startDate']),
      startTime: map['startTime'] != null
          ? TimeOfDay(
        hour: int.parse(map['startTime'].toString().split(':')[0]),
        minute: int.parse(map['startTime'].toString().split(':')[1]),
      )
          : null,
      endTime: map['endTime'] != null
          ? TimeOfDay(
        hour: int.parse(map['endTime'].toString().split(':')[0]),
        minute: int.parse(map['endTime'].toString().split(':')[1]),
      )
          : null,
      repeatType: map['repeatType'] != null
          ? RepeatType.values.firstWhere(
            (e) => e.name == map['repeatType'],
        orElse: () => RepeatType.daily,
      )
          : null,
      reminders: (map['reminders'] as List<dynamic>?)
          ?.map((r) => Reminder.fromMap(r as Map<String, dynamic>))
          .toList() ??
          [],
      days: (map['days'] as Map<String, dynamic>?)
          ?.map((key, value) => MapEntry(key, value as bool)) ??
          {},
      streak: map['streak'] ?? 0,
    );
  }


}
