import 'package:flutter/material.dart';
import 'exam_difficulty.dart';

/// Intermediate entity holding one AI-extracted exam event.
/// Lives only during the import wizard — never persisted directly.
class ExtractedExam {
  final String subject;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String? location;

  // ── User-controlled adjustment (set in the wizard's difficulty step) ──
  final ExamDifficulty difficulty;

  const ExtractedExam({
    required this.subject,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.location,
    this.difficulty = ExamDifficulty.medium,
  });

  ExtractedExam copyWith({
    String? subject,
    DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? location,
    ExamDifficulty? difficulty,
  }) {
    return ExtractedExam(
      subject: subject ?? this.subject,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      difficulty: difficulty ?? this.difficulty,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtractedExam &&
          other.subject == subject &&
          other.date == date;

  @override
  int get hashCode => Object.hash(subject, date);
}

