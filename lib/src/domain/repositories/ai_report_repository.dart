import '../entities/ai_report.dart';
import '../entities/ai_report_request.dart';

abstract class AiReportRepository {
  Future<AiReport> generateWeeklyReport(AiReportRequest request);
}
