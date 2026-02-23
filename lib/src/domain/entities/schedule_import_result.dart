import 'schedule_type.dart';
import 'extracted_class.dart';
import 'extracted_exam.dart';

/// Discriminated union returned by the AI extraction use case.
/// Exactly one of [classes] or [exams] will be non-null based on [type].
class ScheduleImportResult {
  final ScheduleType type;
  final List<ExtractedClass>? classes; // Path A — weekly timetable
  final List<ExtractedExam>? exams;   // Path B — exam schedule

  const ScheduleImportResult.timetable(List<ExtractedClass> classes)
      : type = ScheduleType.weeklyTimetable,
        classes = classes,
        exams = null;

  const ScheduleImportResult.examSchedule(List<ExtractedExam> exams)
      : type = ScheduleType.examSchedule,
        classes = null,
        exams = exams;
}

