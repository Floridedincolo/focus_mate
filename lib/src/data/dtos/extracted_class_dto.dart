import 'package:flutter/material.dart';
import '../../domain/entities/extracted_class.dart';

class ExtractedClassDto {
  final String subject;
  final String day;
  final String startTime; // "HH:MM"
  final String endTime;   // "HH:MM"
  final String? room;

  const ExtractedClassDto({
    required this.subject,
    required this.day,
    required this.startTime,
    required this.endTime,
    this.room,
  });

  factory ExtractedClassDto.fromJson(Map<String, dynamic> json) {
    return ExtractedClassDto(
      subject: json['subject'] as String? ?? 'Unknown',
      day: json['day'] as String? ?? 'Mon',
      startTime: json['start_time'] as String? ?? '09:00',
      endTime: json['end_time'] as String? ?? '10:00',
      room: json['room'] as String?,
    );
  }

  /// Convert to domain entity. Parsing errors fall back to safe defaults.
  ExtractedClass toDomain() {
    return ExtractedClass(
      subject: subject,
      day: day,
      startTime: _parseTime(startTime),
      endTime: _parseTime(endTime),
      room: room,
    );
  }

  static TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return const TimeOfDay(hour: 9, minute: 0);
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }
}

