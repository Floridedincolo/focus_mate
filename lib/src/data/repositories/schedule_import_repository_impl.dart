import 'package:flutter/foundation.dart';
import '../../domain/entities/schedule_import_result.dart';
import '../../domain/repositories/schedule_import_repository.dart';
import '../datasources/schedule_import_datasource.dart';

class ScheduleImportRepositoryImpl implements ScheduleImportRepository {
  final ScheduleImportDataSource _dataSource;

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
      // The datasource already maps Firebase error codes to user-friendly,
      // specific messages (rate-limits, connectivity, server failures).
      // Re-throw them as-is instead of masking everything behind a generic
      // "internet connection" message.
      rethrow;
    }
  }
}
