import 'dart:typed_data';
import '../entities/schedule_import_result.dart';
import '../repositories/schedule_import_repository.dart';

/// Sends image bytes to the AI and returns the structured [ScheduleImportResult].
class ExtractScheduleFromImageUseCase {
  final ScheduleImportRepository _repository;

  ExtractScheduleFromImageUseCase(this._repository);

  Future<ScheduleImportResult> call(Uint8List imageBytes, String mimeType) =>
      _repository.extractScheduleFromImage(imageBytes, mimeType);
}

