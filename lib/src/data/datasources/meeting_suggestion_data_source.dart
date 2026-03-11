import '../../domain/entities/meeting_proposal.dart';
import '../../domain/entities/task.dart';

/// Abstract contract for the AI meeting-suggestion backend.
///
/// Isolates the Gemini / LLM integration from the rest of the app.
/// Implementations live in `implementations/`.
abstract class MeetingSuggestionDataSource {
  /// Sends schedules to the LLM and returns raw [MeetingProposal]s.
  ///
  /// The implementation is responsible for:
  /// 1. Building the prompt (see `SuggestMeetingAiUseCase` for the contract).
  /// 2. Parsing the JSON response.
  /// 3. Converting HH:mm strings to full DateTimes using [targetDate].
  Future<List<MeetingProposal>> suggestMeetings({
    required List<List<Task>> memberSchedules,
    required int meetingDurationMinutes,
    required DateTime targetDate,
    int maxProposals = 3,
  });
}

