// filepath: lib/src/domain/repositories/meeting_suggestion_repository.dart
import '../entities/meeting_proposal.dart';
import '../entities/task.dart';

/// Abstracts the AI back-end used by [SuggestMeetingAiUseCase].
///
/// The algorithmic use case does **not** need a repository — it runs purely
/// in the domain layer. This interface exists solely to decouple the AI
/// call (Gemini via `firebase_ai`) from the use case.
///
/// Implementations live in `lib/src/data/repositories/`.
abstract class MeetingSuggestionRepository {
  /// Sends [memberSchedules] and the requested [meetingDurationMinutes] to the
  /// configured LLM and returns up to [maxProposals] ranked proposals.
  ///
  /// [targetDate] is used so the prompt can provide day-of-week context
  /// (e.g. "Friday afternoon → coffee shop vibe").
  ///
  /// Throws [AiSuggestionException] on network / parsing failures.
  Future<List<MeetingProposal>> suggestMeetingWithAi({
    required List<List<Task>> memberSchedules,
    required int meetingDurationMinutes,
    required DateTime targetDate,
    int maxProposals = 3,
  });
}

