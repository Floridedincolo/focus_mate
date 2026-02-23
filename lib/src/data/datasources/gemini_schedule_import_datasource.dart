import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../dtos/schedule_import_result_dto.dart';

/// Communicates with the Gemini multimodal API to extract schedule data
/// from an image.
///
/// API Key Strategy — dart-define:
/// ─────────────────────────────────────────────────────────────────────
/// The Gemini API key is injected at build time via:
///   flutter run --dart-define=GEMINI_API_KEY=your_key_here
///
/// This means:
///  • The key is NEVER committed to source control.
///  • It's embedded in the binary at compile time (acceptable for a student
///    project; for production you'd rotate to a server-side proxy).
///  • No extra package (dotenv) is needed — just a single String.const.
/// ─────────────────────────────────────────────────────────────────────
class GeminiScheduleImportDataSource {
  static const _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  late final GenerativeModel _model;

  GeminiScheduleImportDataSource() {
    if (_apiKey.isEmpty) {
      throw StateError(
        'GEMINI_API_KEY is not set. '
        'Run with: flutter run --dart-define=GEMINI_API_KEY=<your_key>',
      );
    }
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        // Force the model to return pure JSON — no markdown fences
        responseMimeType: 'application/json',
        temperature: 0.1, // low temperature = more deterministic extraction
      ),
    );
  }

  Future<ScheduleImportResultDto> extractScheduleFromImage(
    Uint8List imageBytes,
    String mimeType,
  ) async {
    final prompt = TextPart(_kSystemPrompt);
    final image = DataPart(mimeType, imageBytes);

    final response = await _model.generateContent([
      Content.multi([prompt, image]),
    ]);

    final rawText = response.text ?? '';
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
        'Could not parse Gemini response as JSON. Raw: $rawText',
      );
    }

    return ScheduleImportResultDto.fromJson(json);
  }

  static String _stripMarkdown(String text) {
    // Remove ```json ... ``` or ``` ... ``` wrappers if present
    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final match = fenced.firstMatch(text);
    if (match != null) return match.group(1)!.trim();
    return text.trim();
  }
}

// ── System Prompt ────────────────────────────────────────────────────────────
// Kept as a top-level constant so it's easy to tweak without touching class logic.
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

