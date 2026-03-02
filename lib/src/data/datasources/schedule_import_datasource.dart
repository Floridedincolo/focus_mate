import 'dart:typed_data';
import '../dtos/schedule_import_result_dto.dart';

/// Abstract contract for schedule-import data sources.
///
/// Implementations may call a local AI SDK ([GeminiScheduleImportDataSource])
/// or a remote Cloud Function ([CloudFunctionScheduleImportDataSource]).
abstract class ScheduleImportDataSource {
  Future<ScheduleImportResultDto> extractScheduleFromImage(
    Uint8List imageBytes,
    String mimeType,
  );
}

