// filepath: lib/src/domain/usecases/suggest_meeting_ai_use_case.dart
import '../entities/meeting_location.dart';
import '../entities/meeting_proposal.dart';
import '../entities/task.dart';
import '../repositories/meeting_suggestion_repository.dart';

/// Delegates to the AI back-end to find optimal meeting slots and suggest
/// a contextually appropriate location type for the group.
class SuggestMeetingAiUseCase {
  final MeetingSuggestionRepository _repository;

  const SuggestMeetingAiUseCase(this._repository);

  Future<List<MeetingProposal>> call({
    required List<List<Task>> memberSchedules,
    required int meetingDurationMinutes,
    required DateTime targetDate,
    int maxProposals = 3,
    List<(MeetingLocation? home, MeetingLocation? work)>? memberLocations,
  }) {
    if (memberSchedules.isEmpty) {
      throw ArgumentError('Provide at least one member schedule.');
    }
    if (meetingDurationMinutes <= 0) {
      throw ArgumentError('meetingDurationMinutes must be positive.');
    }

    return _repository.suggestMeetingWithAi(
      memberSchedules: memberSchedules,
      meetingDurationMinutes: meetingDurationMinutes,
      targetDate: targetDate,
      maxProposals: maxProposals,
      memberLocations: memberLocations,
    );
  }
}
