import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../entities/extracted_exam.dart';
import '../entities/exam_difficulty.dart';
import '../entities/task.dart';

/// Generates one-off spaced study [Task]s leading up to each exam.
///
/// Algorithm
/// ─────────
/// 1. daysUntilExam  = exam.date − today (clamped to ≥ 1)
/// 2. sessionCount   = difficulty.sessionCount, CAPPED to daysUntilExam
///    (if the exam is tomorrow and difficulty is Hard, you still only get
///     1 session — the day before — not 5 overlapping sessions)
/// 3. Sessions are distributed with increasing density toward the exam:
///      - The LAST session is always 1 day before the exam.
///      - The FIRST session is at daysUntilExam * 0.6 days before the exam.
///      - Remaining sessions are evenly spaced in between.
/// 4. Study duration per session = totalStudyHours / sessionCount (rounded
///    to nearest 15 min, min 30 min, max 120 min).
/// 5. Default study start time: 17:00 (adjustable in the future).
class GenerateExamPrepTasksUseCase {
  static const _defaultStudyStartHour = 17;
  static const _uuid = Uuid();
  String _newId() => _uuid.v4();

  Future<List<Task>> call({
    required List<ExtractedExam> exams,
    required DateTime today,
  }) async {
    final todayOnly = DateTime(today.year, today.month, today.day);
    final List<Task> result = [];

    for (final exam in exams) {
      final examDay = DateTime(exam.date.year, exam.date.month, exam.date.day);
      final daysUntilExam = examDay.difference(todayOnly).inDays;

      if (daysUntilExam <= 0) continue; // exam already passed

      final difficulty = exam.difficulty;
      final rawSessionCount = difficulty.sessionCount;

      // Cap sessions to available days (max 1 session per day, last day is
      // always 1 day before the exam, so usable days = daysUntilExam)
      final sessionCount = rawSessionCount.clamp(1, daysUntilExam);

      // Session duration in minutes
      final totalMinutes = (difficulty.totalStudyHours * 60).round();
      final rawMinutesPerSession = (totalMinutes / sessionCount).round();
      final minutesPerSession = _roundToNearest15(rawMinutesPerSession)
          .clamp(30, 120);

      // Compute session dates (days before exam, counting back from 1)
      final sessionDates = _computeSessionDates(
        examDay: examDay,
        daysUntilExam: daysUntilExam,
        sessionCount: sessionCount,
      );

      for (final sessionDate in sessionDates) {
        final startTime = const TimeOfDay(hour: _defaultStudyStartHour, minute: 0);
        final endHour = _defaultStudyStartHour + minutesPerSession ~/ 60;
        final endMinute = minutesPerSession % 60;
        final endTime = TimeOfDay(hour: endHour, minute: endMinute);

        result.add(Task(
          id: _newId(),
          title: 'Prep: ${exam.subject}',
          oneTime: true,
          startDate: sessionDate,
          startTime: startTime,
          endTime: endTime,
          repeatType: null,
          days: const {},
        ));
      }

      // Also create the actual exam task itself (one-off, marked as oneTime)
      result.add(Task(
        id: _newId(),
        title: '📝 Exam: ${exam.subject}',
        oneTime: true,
        startDate: exam.date,
        startTime: exam.startTime,
        endTime: exam.endTime,
        repeatType: null,
        days: const {},
      ));
    }

    return result;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  List<DateTime> _computeSessionDates({
    required DateTime examDay,
    required int daysUntilExam,
    required int sessionCount,
  }) {
    if (sessionCount == 1) {
      // Only one slot: the day before the exam
      return [examDay.subtract(const Duration(days: 1))];
    }

    // First session starts roughly at 60% through the available time
    // (i.e., the student has 40% of the remaining days as a "ramp-up" buffer)
    final firstOffset = (daysUntilExam * 0.6).round().clamp(2, daysUntilExam - 1);
    final lastOffset = 1; // always 1 day before

    // Spread sessions evenly between firstOffset and lastOffset (days before exam)
    final List<DateTime> dates = [];
    for (int i = 0; i < sessionCount; i++) {
      final fraction = i / (sessionCount - 1); // 0.0 → 1.0
      final daysBeforeExam =
          (firstOffset + (lastOffset - firstOffset) * fraction).round();
      dates.add(examDay.subtract(Duration(days: daysBeforeExam)));
    }

    // De-duplicate (edge case when daysUntilExam is very small)
    final seen = <String>{};
    return dates.where((d) {
      final key = '${d.year}-${d.month}-${d.day}';
      return seen.add(key);
    }).toList();
  }

  int _roundToNearest15(int minutes) {
    return ((minutes / 15).round() * 15).clamp(15, 10000);
  }
}

