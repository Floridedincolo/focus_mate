import 'package:flutter/foundation.dart';
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
    try {
      final dto = await _dataSource.extractScheduleFromImage(imageBytes, mimeType);
      return dto.toDomain();
    } on FormatException catch (e) {
      if (kDebugMode) debugPrint('🔥 Schedule parse error: $e');
      throw Exception(
        'The AI could not read your schedule clearly. '
        'Please try with a clearer photo.',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('🔥 Schedule import error: $e');
      // Re-throw rate-limit messages as-is (they're already user-friendly)
      if (e.toString().contains('Please wait')) rethrow;
      throw Exception(
        'Failed to analyse your schedule. '
        'Please check your internet connection and try again.',
      );
    }
  }
}
