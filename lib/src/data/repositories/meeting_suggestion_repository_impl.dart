import '../../domain/entities/meeting_location.dart';
import '../../domain/entities/meeting_proposal.dart';
import '../../domain/entities/task.dart';
import '../../domain/errors/domain_errors.dart';
import '../../domain/repositories/meeting_suggestion_repository.dart';
import '../datasources/location_search_service.dart';
import '../datasources/meeting_suggestion_data_source.dart';

/// Concrete implementation of [MeetingSuggestionRepository].
///
/// Implements a **2-step pipeline**:
/// 1. [MeetingSuggestionDataSource] (Gemini) → raw proposals with GPS midpoint
///    + place keyword.
/// 2. [LocationSearchService] (Places API / mock) → resolves each midpoint +
///    keyword into a real [MeetingLocation] with name and coordinates.
class MeetingSuggestionRepositoryImpl implements MeetingSuggestionRepository {
  final MeetingSuggestionDataSource _dataSource;
  final LocationSearchService _locationService;

  MeetingSuggestionRepositoryImpl(this._dataSource, this._locationService);

  @override
  Future<List<MeetingProposal>> suggestMeetingWithAi({
    required List<List<Task>> memberSchedules,
    required int meetingDurationMinutes,
    required DateTime targetDate,
    int maxProposals = 3,
  }) async {
    // ── Step 1: Gemini → raw proposals (time + GPS midpoint + keyword) ──
    final rawProposals = await _dataSource.suggestMeetings(
      memberSchedules: memberSchedules,
      meetingDurationMinutes: meetingDurationMinutes,
      targetDate: targetDate,
      maxProposals: maxProposals,
    );

    // ── Step 2: Places API → resolve each proposal's location ───────────
    try {
      final resolved = await Future.wait(
        rawProposals.map((raw) async {
          try {
            final location = await _locationService.findNearestPlace(
              latitude: raw.targetLatitude,
              longitude: raw.targetLongitude,
              keyword: raw.placeKeyword,
            );
            return MeetingProposal(
              startTime: raw.startTime,
              endTime: raw.endTime,
              location: location,
              source: ProposalSource.ai,
              aiRationale: raw.rationale,
            );
          } catch (_) {
            // If place lookup fails for one proposal, fall back to keyword.
            return MeetingProposal(
              startTime: raw.startTime,
              endTime: raw.endTime,
              location: MeetingLocation(
                name: _capitalize(raw.placeKeyword),
                latitude: raw.targetLatitude,
                longitude: raw.targetLongitude,
              ),
              source: ProposalSource.ai,
              aiRationale: raw.rationale,
            );
          }
        }),
      );
      return resolved;
    } on AiSuggestionException {
      rethrow;
    } catch (e) {
      throw AiSuggestionException(
        'AI meeting suggestion failed: $e',
        e is Exception ? e : null,
      );
    }
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

