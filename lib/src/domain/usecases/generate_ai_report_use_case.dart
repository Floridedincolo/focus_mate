import '../entities/ai_report.dart';
import '../entities/ai_report_request.dart';
import '../repositories/ai_report_repository.dart';

class GenerateAiReportUseCase {
  final AiReportRepository _repository;

  GenerateAiReportUseCase(this._repository);

  Future<AiReport> call(AiReportRequest request) {
    return _repository.generateWeeklyReport(request);
  }
}
