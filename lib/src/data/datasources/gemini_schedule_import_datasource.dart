import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart';
import '../dtos/schedule_import_result_dto.dart';

/// Communicates with Gemini via the Firebase AI SDK to extract
/// schedule data from an image.
///
/// Security Strategy — Firebase AI (Vertex AI backend):
/// ─────────────────────────────────────────────────────────────────────
/// Instead of embedding a raw Gemini API key in the client binary
/// (which can be extracted via reverse engineering), we use the
/// `firebase_ai` package with the Vertex AI backend, which
/// authenticates through the existing Firebase project credentials.
///
/// Benefits:
///  • NO API key is stored in the client binary or source code.
///  • Authentication is handled by Firebase SDK automatically.
///  • Access can be further restricted with Firebase App Check.
///  • Billing goes through the linked Google Cloud project.
///
/// Prerequisites:
///  • Enable "Vertex AI in Firebase" API in the Firebase / GCP console.
///  • Firebase must be initialised before this class is used.
/// ─────────────────────────────────────────────────────────────────────
class GeminiScheduleImportDataSource {
  static const _kTimeoutDuration = Duration(seconds: 60);
  static const _kMaxRetries = 2;

  late final GenerativeModel _model;

  /// Tracks the last request timestamp for simple client-side rate limiting.
  DateTime? _lastRequestTime;
  static const _kMinRequestInterval = Duration(seconds: 5);

  GeminiScheduleImportDataSource() {
    _model = FirebaseAI.vertexAI().generativeModel(
      model: 'gemini-2.0-flash',
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.1,
      ),
    );
  }

  Future<ScheduleImportResultDto> extractScheduleFromImage(
    Uint8List imageBytes,
    String mimeType,
  ) async {
    // Client-side rate limiting to avoid accidental rapid-fire requests
    _enforceRateLimit();

    final prompt = TextPart(_kSystemPrompt);
    final image = InlineDataPart(mimeType, imageBytes);

    final rawText = await _sendWithRetry(prompt, image);

    if (rawText.isEmpty) {
      throw Exception('Gemini returned an empty response.');
    }

    // Strip markdown fences if the model ignores responseMimeType
    final cleaned = _stripMarkdown(rawText);

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException(
        'Could not parse Gemini response as JSON.\n'
        'Raw response (first 500 chars): ${rawText.substring(0, rawText.length.clamp(0, 500))}',
      );
    }

    return ScheduleImportResultDto.fromJson(json);
  }

  /// Sends the request with automatic retry for transient failures.
  Future<String> _sendWithRetry(TextPart prompt, InlineDataPart image) async {
    Object? lastError;

    for (int attempt = 0; attempt <= _kMaxRetries; attempt++) {
      try {
        final response = await _model
            .generateContent([
              Content.multi([prompt, image]),
            ])
            .timeout(_kTimeoutDuration);

        return response.text ?? '';
      } on FirebaseAIException catch (e) {
        // Don't retry on content safety / invalid argument errors
        if (e.toString().contains('SAFETY') ||
            e.toString().contains('INVALID_ARGUMENT')) {
          rethrow;
        }
        lastError = e;
      } catch (e) {
        lastError = e;
      }

      // Exponential back-off before retrying
      if (attempt < _kMaxRetries) {
        await Future.delayed(Duration(seconds: (attempt + 1) * 2));
      }
    }

    throw Exception(
      'Gemini request failed after ${_kMaxRetries + 1} attempts. '
      'Last error: $lastError',
    );
  }

  void _enforceRateLimit() {
    final now = DateTime.now();
    if (_lastRequestTime != null &&
        now.difference(_lastRequestTime!) < _kMinRequestInterval) {
      throw Exception(
        'Please wait a few seconds before sending another request.',
      );
    }
    _lastRequestTime = now;
  }

  static String _stripMarkdown(String text) {
    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final match = fenced.firstMatch(text);
    if (match != null) return match.group(1)!.trim();
    return text.trim();
  }
}

// ── System Prompt ────────────────────────────────────────────────────────────
const _kSystemPrompt = '''
You are an expert academic schedule parser.
Your task is to analyze the provided image of a schedule and extract all data into a strict JSON format.

RULES:
1. Output ONLY raw JSON. No markdown, no code fences, no explanation text.
2. Determine if the image is a "weekly_timetable" (recurring classes repeating every week) or an "exam_schedule" (specific one-time exam dates).
3. Use ONLY the schemas defined below. Do not add extra fields.
4. Times must be in 24-hour "HH:MM" format (e.g., "09:00", "14:30").
5. Days must be exactly one of: "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun".
6. Dates must be in "YYYY-MM-DD" format.
7. If a field is not visible in the image, use null.
8. If you cannot determine the schedule type with confidence, default to "weekly_timetable".
9. Ignore any handwritten notes, doodles, or non-schedule content in the image.
10. If the image does not contain a recognizable schedule, return: {"type": "weekly_timetable", "classes": []}

SCHEMA FOR WEEKLY TIMETABLE:
{
  "type": "weekly_timetable",
  "classes": [
    {
      "subject": "<string: full subject/course name>",
      "day": "<Mon|Tue|Wed|Thu|Fri|Sat|Sun>",
      "start_time": "<HH:MM>",
      "end_time": "<HH:MM>",
      "room": "<string or null>"
    }
  ]
}

SCHEMA FOR EXAM SCHEDULE:
{
  "type": "exam_schedule",
  "exams": [
    {
      "subject": "<string: full subject/course name>",
      "date": "<YYYY-MM-DD>",
      "start_time": "<HH:MM>",
      "end_time": "<HH:MM>",
      "location": "<string or null>"
    }
  ]
}

Now analyze the image and return the JSON.
''';
