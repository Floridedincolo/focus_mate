import '../../domain/entities/ai_report_request.dart';
import '../dtos/ai_report_dto.dart';

abstract class AiReportDataSource {
  Future<AiReportDto> generateWeeklyReport(AiReportRequest request);
}
