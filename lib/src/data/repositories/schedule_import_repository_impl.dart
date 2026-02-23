import 'dart:typed_data';
import '../../domain/entities/schedule_import_result.dart';
import '../../domain/repositories/schedule_import_repository.dart';
import '../datasources/gemini_schedule_import_datasource.dart';

class ScheduleImportRepositoryImpl implements ScheduleImportRepository {
  final GeminiScheduleImportDataSource _dataSource;

  ScheduleImportRepositoryImpl(this._dataSource);

  @override
  Future<ScheduleImportResult> extractScheduleFromImage(
    Uint8List imageBytes,
    String mimeType,
  ) async {
    final dto = await _dataSource.extractScheduleFromImage(imageBytes, mimeType);
    return dto.toDomain();
  }
}

