import 'package:flutter/material.dart';
class Reminder {
  final TimeOfDay time;
  final Map<String, bool> days;
  final String message;
  Reminder({
    required this.time,
    required this.days,
    this.message=' ',
  });
  Map<String, dynamic> toMap() {
    return {
      'time': "${time.hour}:${time.minute}",
      'days': days,
      'message': message,
    };
  }
  factory Reminder.fromMap(Map<String, dynamic> map) {//factory constructors are more flexible than normal constructors can validate doesnt have to rturn new instance everytime
    return Reminder(
      time: TimeOfDay(
        hour: int.parse(map['time'].toString().split(':')[0]),
        minute: int.parse(map['time'].toString().split(':')[1]),
      ),
      days: (map['days'] as Map<String,dynamic>?)?.map((key,value)=>MapEntry(key,value as bool))??{},
      message: map['message']??' ',
    );
  }
}
