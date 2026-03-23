import '../dtos/gemini_raw_proposal.dart';
import '../../domain/entities/task.dart';

/// Abstract contract for the AI meeting-suggestion backend.
///
/// Isolates the Gemini / LLM integration from the rest of the app.
/// Implementations live in `implementations/`.
///
/// Returns [GeminiRawProposal]s (time + GPS midpoint + keyword).
/// The repository layer resolves these into final [MeetingProposal]s by
/// looking up real places via [LocationSearchService].
abstract class MeetingSuggestionDataSource {
  /// Sends schedules to the LLM and returns raw proposals containing
  /// time slots, a GPS midpoint, and a place keyword.
  ///
  /// The implementation is responsible for:
  /// 1. Building the prompt.
  /// 2. Parsing the JSON response.
  /// 3. Converting HH:mm strings to full DateTimes using [targetDate].
  Future<List<GeminiRawProposal>> suggestMeetings({
    required List<List<Task>> memberSchedules,
    required int meetingDurationMinutes,
    required DateTime targetDate,
    int maxProposals = 3,
  });
}

