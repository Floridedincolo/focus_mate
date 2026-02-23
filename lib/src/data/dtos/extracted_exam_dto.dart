import 'package:flutter/material.dart';
import '../../domain/entities/extracted_exam.dart';

class ExtractedExamDto {
  final String subject;
  final String date;      // "YYYY-MM-DD"
  final String startTime; // "HH:MM"
  final String endTime;   // "HH:MM"
  final String? location;

  const ExtractedExamDto({
    required this.subject,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.location,
  });

  factory ExtractedExamDto.fromJson(Map<String, dynamic> json) {
    return ExtractedExamDto(
      subject: json['subject'] as String? ?? 'Unknown',
      date: json['date'] as String? ?? DateTime.now().toIso8601String().substring(0, 10),
      startTime: json['start_time'] as String? ?? '09:00',
      endTime: json['end_time'] as String? ?? '11:00',
      location: json['location'] as String?,
    );
  }

  ExtractedExam toDomain() {
    return ExtractedExam(
      subject: subject,
      date: DateTime.tryParse(date) ?? DateTime.now(),
      startTime: _parseTime(startTime),
      endTime: _parseTime(endTime),
      location: location,
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

