import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import '../../dtos/schedule_import_result_dto.dart';
import '../schedule_import_datasource.dart';

/// Data source that routes schedule extraction through a Firebase
/// Cloud Function (`extractSchedule`).
///
/// Benefits over the legacy [GeminiScheduleImportDataSource]:
///  • The AI system prompt lives server-side — editable instantly
///    without an app update.
///  • Server-side rate limiting, auth verification, and image-size
///    validation prevent abuse.
///  • The API key / Vertex AI credentials never leave the server.
class CloudFunctionScheduleImportDataSource implements ScheduleImportDataSource {
  final FirebaseFunctions _functions;

  CloudFunctionScheduleImportDataSource(this._functions);

  @override
  Future<ScheduleImportResultDto> extractScheduleFromImage(
    Uint8List imageBytes,
    String mimeType,
  ) async {
    final callable = _functions.httpsCallable(
      'extractSchedule',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
    );

    final HttpsCallableResult<dynamic> result;
    try {
      result = await callable.call<dynamic>({
        'imageBase64': base64Encode(imageBytes),
        'mimeType': mimeType,
      });
    } on FirebaseFunctionsException catch (e) {
      // Map Cloud Function error codes to user-friendly messages.
      switch (e.code) {
        case 'unauthenticated':
          throw Exception('Please sign in to import a schedule.');
        case 'resource-exhausted':
          throw Exception(
            e.message ?? 'Please wait a few seconds before trying again.',
          );
        case 'invalid-argument':
          throw Exception(
            e.message ?? 'The image could not be processed. Please try another.',
          );
        default:
          throw Exception(
            e.message ??
                'Failed to analyse your schedule. Please try again later.',
          );
      }
    }

    final jsonString = jsonEncode(result.data);

    // 2. Îl decodăm înapoi. Acum Dart va crea automat un Map<String, dynamic> perfect și curat, pe toate nivelurile!
    final cleanJson = jsonDecode(jsonString) as Map<String, dynamic>;

    // 3. Îl trimitem către modelul tău
    return ScheduleImportResultDto.fromJson(cleanJson);
  }
}

