import '../../domain/entities/schedule_import_result.dart';
import 'extracted_class_dto.dart';

class ScheduleImportResultDto {
  final List<ExtractedClassDto>? classes;

  const ScheduleImportResultDto({this.classes});

  factory ScheduleImportResultDto.fromJson(Map<String, dynamic> json) {
    // Accept both "weekly_timetable" and "exam_schedule" type images,
    // but always extract only classes. If the image was an exam schedule
    // we return an empty class list.
    final rawClasses = json['classes'] as List<dynamic>?;

    return ScheduleImportResultDto(
      classes: rawClasses
          ?.map((e) => ExtractedClassDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  ScheduleImportResult toDomain() {
    final domainClasses = (classes ?? []).map((c) => c.toDomain()).toList();
    return ScheduleImportResult(domainClasses);
  }
}

