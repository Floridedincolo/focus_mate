// filepath: lib/src/domain/usecases/suggest_meeting_ai_use_case.dart
import '../entities/meeting_proposal.dart';
import '../entities/task.dart';
import '../repositories/meeting_suggestion_repository.dart';

/// Delegates to the AI back-end to find optimal meeting slots and suggest
/// a contextually appropriate location type for the group.
///
/// ### Responsibility split
/// | Layer       | Does what                                              |
/// |-------------|--------------------------------------------------------|
/// | Domain (here) | Validates inputs, orchestrates the call              |
/// | Data layer  | Builds the Gemini prompt, parses the JSON response     |
///
/// ### Prompt contract (handled in the data layer)
/// The data layer implementation must build a prompt roughly like:
/// ```
/// Analyse the following schedules for {N} people.
/// Date: {weekday}, {date}
/// Requested meeting duration: {X} minutes
///
/// Schedules:
///   Person 1: [09:00-10:30 Mathematics, 14:00-15:30 Physics]
///   Person 2: [10:00-11:30 CS, 16:00-17:00 Sports]
///   ...
///
/// Task:
/// 1. Find {maxProposals} optimal time slots for a meeting of {X} minutes
///    where ALL members are free.
/// 2. Based on context (time of day, preceding activities), suggest a
///    location type (e.g. Coffee Shop, Restaurant, Park, Library).
/// 3. Respond EXCLUSIVELY in JSON following the schema below.
///
/// JSON schema:
/// {
///   "proposals": [
///     {
///       "startTime": "HH:mm",
///       "endTime":   "HH:mm",
///       "locationName": "Coffee Shop",
///       "rationale": "Brief explanation"
///     }
///   ]
/// }
/// ```
///
/// ### Example usage
/// ```dart
/// final useCase = SuggestMeetingAiUseCase(meetingSuggestionRepository);
/// final proposals = await useCase(
///   memberSchedules: [alicesTasks, bobsTasks],
///   meetingDurationMinutes: 90,
///   targetDate: DateTime(2026, 3, 15),
/// );
/// ```
class SuggestMeetingAiUseCase {
  final MeetingSuggestionRepository _repository;

  const SuggestMeetingAiUseCase(this._repository);

  /// Returns up to [maxProposals] AI-generated [MeetingProposal]s.
  ///
  /// Throws [AiSuggestionException] (see `domain_errors.dart`) on failure.
  Future<List<MeetingProposal>> call({
    required List<List<Task>> memberSchedules,
    required int meetingDurationMinutes,
    required DateTime targetDate,
    int maxProposals = 3,
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
    );
  }
}

