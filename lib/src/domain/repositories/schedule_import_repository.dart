import 'dart:typed_data';
import '../entities/schedule_import_result.dart';

/// Contract for the schedule import data layer.
/// The only operation is sending image bytes to the AI and
/// getting back a parsed [ScheduleImportResult].
abstract class ScheduleImportRepository {
  Future<ScheduleImportResult> extractScheduleFromImage(
    Uint8List imageBytes,
    String mimeType,
  );
}

