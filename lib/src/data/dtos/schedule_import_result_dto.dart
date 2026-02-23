import '../../domain/entities/schedule_import_result.dart';
import 'extracted_class_dto.dart';
import 'extracted_exam_dto.dart';

class ScheduleImportResultDto {
  final String type; // "weekly_timetable" | "exam_schedule"
  final List<ExtractedClassDto>? classes;
  final List<ExtractedExamDto>? exams;

  const ScheduleImportResultDto({
    required this.type,
    this.classes,
    this.exams,
  });

  factory ScheduleImportResultDto.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'weekly_timetable';

    final rawClasses = json['classes'] as List<dynamic>?;
    final rawExams = json['exams'] as List<dynamic>?;

    return ScheduleImportResultDto(
      type: type,
      classes: rawClasses
          ?.map((e) => ExtractedClassDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      exams: rawExams
          ?.map((e) => ExtractedExamDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  ScheduleImportResult toDomain() {
    if (type == 'exam_schedule') {
      final domainExams = (exams ?? []).map((e) => e.toDomain()).toList();
      return ScheduleImportResult.examSchedule(domainExams);
    }
    final domainClasses = (classes ?? []).map((c) => c.toDomain()).toList();
    return ScheduleImportResult.timetable(domainClasses);
  }
}

