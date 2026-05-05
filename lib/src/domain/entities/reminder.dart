import 'package:flutter/material.dart';

enum ReminderType { notification, alarm }

class Reminder {
  final TimeOfDay time;
  final Map<String, bool> days;
  final String message;
  final ReminderType type;

  Reminder({
    required this.time,
    required this.days,
    this.message = ' ',
    this.type = ReminderType.notification,
  });

  Map<String, dynamic> toMap() {
    return {
      'time': "${time.hour}:${time.minute}",
      'days': days,
      'message': message,
      'type': type.name,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      time: TimeOfDay(
        hour: int.parse(map['time'].toString().split(':')[0]),
        minute: int.parse(map['time'].toString().split(':')[1]),
      ),
      days:
          (map['days'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value as bool),
          ) ??
          {},
      message: map['message'] ?? ' ',
      type: ReminderType.values.firstWhere(
        (t) => t.name == (map['type'] as String?),
        orElse: () => ReminderType.notification,
      ),
    );
  }

  Reminder copyWith({
    TimeOfDay? time,
    Map<String, bool>? days,
    String? message,
    ReminderType? type,
  }) {
    return Reminder(
      time: time ?? this.time,
      days: days ?? this.days,
      message: message ?? this.message,
      type: type ?? this.type,
    );
  }
}
