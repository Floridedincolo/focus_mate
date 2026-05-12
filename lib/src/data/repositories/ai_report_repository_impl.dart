import '../../domain/entities/ai_report.dart';
import '../../domain/entities/ai_report_request.dart';
import '../../domain/repositories/ai_report_repository.dart';
import '../datasources/ai_report_data_source.dart';

class AiReportRepositoryImpl implements AiReportRepository {
  final AiReportDataSource _dataSource;

  AiReportRepositoryImpl(this._dataSource);

  @override
  Future<AiReport> generateWeeklyReport(AiReportRequest request) async {
    final dto = await _dataSource.generateWeeklyReport(request);
    return dto.toEntity();
  }
}
