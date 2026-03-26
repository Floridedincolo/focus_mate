import '../dtos/gemini_raw_proposal.dart';
import '../../domain/entities/meeting_location.dart';
import '../../domain/entities/task.dart';

/// Abstract contract for the AI meeting-suggestion backend.
///
/// Returns [GeminiRawProposal]s (time + GPS midpoint + keyword).
/// The repository layer resolves these into final [MeetingProposal]s by
/// looking up real places via [LocationSearchService].
abstract class MeetingSuggestionDataSource {
  Future<List<GeminiRawProposal>> suggestMeetings({
    required List<List<Task>> memberSchedules,
    required int meetingDurationMinutes,
    required DateTime targetDate,
    int maxProposals = 3,
    List<(MeetingLocation? home, MeetingLocation? work)>? memberLocations,
  });
}
