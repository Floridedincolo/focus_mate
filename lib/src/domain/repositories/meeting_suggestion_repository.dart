// filepath: lib/src/domain/repositories/meeting_suggestion_repository.dart
import '../entities/meeting_location.dart';
import '../entities/meeting_proposal.dart';
import '../entities/task.dart';

/// Abstracts the AI back-end used by [SuggestMeetingAiUseCase].
abstract class MeetingSuggestionRepository {
  Future<List<MeetingProposal>> suggestMeetingWithAi({
    required List<List<Task>> memberSchedules,
    required int meetingDurationMinutes,
    required DateTime targetDate,
    int maxProposals = 3,
    List<(MeetingLocation? home, MeetingLocation? work)>? memberLocations,
  });
}
