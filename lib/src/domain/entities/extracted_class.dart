import 'package:flutter/material.dart';

/// Intermediate entity holding one AI-extracted recurring class.
/// Lives only during the import wizard — never persisted directly.
class ExtractedClass {
  final String subject;

  /// Three-letter day abbreviation: "Mon" | "Tue" | "Wed" | "Thu" | "Fri" | "Sat" | "Sun"
  final String day;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String? room;

  // ── User-controlled adjustments (populated in the wizard's adjustment step) ──
  final bool needsHomework;

  /// Total homework hours per week the student estimates for this subject.
  final double homeworkHoursPerWeek;

  /// Whether this subject has a final exam.
  final bool hasFinalExam;

  /// End date for weekly tasks (or exam date if [hasFinalExam] is true).
  /// Defaults to 14 weeks from import if not set.
  final DateTime? endDate;

  const ExtractedClass({
    required this.subject,
    required this.day,
    required this.startTime,
    required this.endTime,
    this.room,
    this.needsHomework = false,
    this.homeworkHoursPerWeek = 1.0,
    this.hasFinalExam = false,
    this.endDate,
  });

  ExtractedClass copyWith({
    String? subject,
    String? day,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? room,
    bool? needsHomework,
    double? homeworkHoursPerWeek,
    bool? hasFinalExam,
    DateTime? endDate,
  }) {
    return ExtractedClass(
      subject: subject ?? this.subject,
      day: day ?? this.day,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      room: room ?? this.room,
      needsHomework: needsHomework ?? this.needsHomework,
      homeworkHoursPerWeek: homeworkHoursPerWeek ?? this.homeworkHoursPerWeek,
      hasFinalExam: hasFinalExam ?? this.hasFinalExam,
      endDate: endDate ?? this.endDate,
    );
  }

  /// Returns a copy with [endDate] explicitly set to `null`.
  ExtractedClass clearEndDate() {
    return ExtractedClass(
      subject: subject,
      day: day,
      startTime: startTime,
      endTime: endTime,
      room: room,
      needsHomework: needsHomework,
      homeworkHoursPerWeek: homeworkHoursPerWeek,
      hasFinalExam: hasFinalExam,
      endDate: null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtractedClass &&
          other.subject == subject &&
          other.day == day &&
          other.startTime == startTime &&
          other.endTime == endTime;

  @override
  int get hashCode => Object.hash(subject, day, startTime, endTime);
}

