import '../../domain/entities/meeting_proposal.dart';

/// Wizard steps for the Plan Meeting flow.
enum MeetingSuggestionStep {
  selectFriends,
  configure, // pick date range, duration, method
  loading,
  results,
  error,
}

/// Immutable state for the meeting suggestion wizard.
class MeetingSuggestionState {
  final MeetingSuggestionStep step;
  final List<String> selectedFriendUids;
  final List<String> selectedFriendNames;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final int meetingDurationMinutes;
  final ProposalSource proposalSource;
  final List<MeetingProposal> proposals;
  final String? errorMessage;

  const MeetingSuggestionState({
    this.step = MeetingSuggestionStep.selectFriends,
    this.selectedFriendUids = const [],
    this.selectedFriendNames = const [],
    this.rangeStart,
    this.rangeEnd,
    this.meetingDurationMinutes = 60,
    this.proposalSource = ProposalSource.algorithmic,
    this.proposals = const [],
    this.errorMessage,
  });

  MeetingSuggestionState copyWith({
    MeetingSuggestionStep? step,
    List<String>? selectedFriendUids,
    List<String>? selectedFriendNames,
    DateTime? rangeStart,
    DateTime? rangeEnd,
    int? meetingDurationMinutes,
    ProposalSource? proposalSource,
    List<MeetingProposal>? proposals,
    String? errorMessage,
  }) {
    return MeetingSuggestionState(
      step: step ?? this.step,
      selectedFriendUids: selectedFriendUids ?? this.selectedFriendUids,
      selectedFriendNames: selectedFriendNames ?? this.selectedFriendNames,
      rangeStart: rangeStart ?? this.rangeStart,
      rangeEnd: rangeEnd ?? this.rangeEnd,
      meetingDurationMinutes:
          meetingDurationMinutes ?? this.meetingDurationMinutes,
      proposalSource: proposalSource ?? this.proposalSource,
      proposals: proposals ?? this.proposals,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

