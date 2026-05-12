import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../domain/entities/ai_report_request.dart';
import '../../dtos/ai_report_dto.dart';
import '../ai_report_data_source.dart';

/// Routes weekly-report generation through the `generateAiReport`
/// Cloud Function. The Vertex AI prompt and credentials never leave
/// the server, mirroring the architecture used for schedule import.
class CloudFunctionAiReportDataSource implements AiReportDataSource {
  final FirebaseFunctions _functions;

  CloudFunctionAiReportDataSource(this._functions);

  @override
  Future<AiReportDto> generateWeeklyReport(AiReportRequest request) async {
    final callable = _functions.httpsCallable(
      'generateAiReport',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );

    final HttpsCallableResult<dynamic> result;
    try {
      result = await callable.call<dynamic>(request.toJson());
    } on FirebaseFunctionsException catch (e) {
      switch (e.code) {
        case 'unauthenticated':
          throw Exception('Please sign in to generate a report.');
        case 'resource-exhausted':
          throw Exception(
            e.message ??
                'Please wait a few moments before generating another report.',
          );
        case 'invalid-argument':
          throw Exception(
            e.message ?? 'The statistics payload was rejected by the server.',
          );
        default:
          throw Exception(
            e.message ?? 'Failed to generate the report. Please try again.',
          );
      }
    }

    // Round-trip through JSON to normalise the dynamic map shape returned
    // by the Functions SDK (same pattern as the schedule import data source).
    final cleanJson =
        jsonDecode(jsonEncode(result.data)) as Map<String, dynamic>;
    return AiReportDto.fromJson(cleanJson);
  }
}
