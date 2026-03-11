import '../../domain/entities/meeting_proposal.dart';
import '../../domain/entities/task.dart';
import '../../domain/errors/domain_errors.dart';
import '../../domain/repositories/meeting_suggestion_repository.dart';
import '../datasources/meeting_suggestion_data_source.dart';

/// Concrete implementation of [MeetingSuggestionRepository].
///
/// Delegates to [MeetingSuggestionDataSource] (Gemini) and wraps errors
/// in domain-level [AiSuggestionException].
class MeetingSuggestionRepositoryImpl implements MeetingSuggestionRepository {
  final MeetingSuggestionDataSource _dataSource;

  MeetingSuggestionRepositoryImpl(this._dataSource);

  @override
  Future<List<MeetingProposal>> suggestMeetingWithAi({
    required List<List<Task>> memberSchedules,
    required int meetingDurationMinutes,
    required DateTime targetDate,
    int maxProposals = 3,
  }) async {
    try {
      return await _dataSource.suggestMeetings(
        memberSchedules: memberSchedules,
        meetingDurationMinutes: meetingDurationMinutes,
        targetDate: targetDate,
        maxProposals: maxProposals,
      );
    } on AiSuggestionException {
      rethrow; // Already a domain error
    } catch (e) {
      throw AiSuggestionException(
        'AI meeting suggestion failed: $e',
        e is Exception ? e : null,
      );
    }
  }
}

