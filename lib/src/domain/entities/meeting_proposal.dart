// filepath: lib/src/domain/entities/meeting_proposal.dart
import 'meeting_location.dart';

/// A single candidate time-slot + location returned by either the algorithmic
/// or the AI meeting-suggestion use case.
///
/// Multiple [MeetingProposal]s are bundled together in the list returned by
/// both `SuggestMeetingAlgorithmicUseCase` and `SuggestMeetingAiUseCase`.
///
/// Firestore path (when persisted): `meetingProposals/{proposalId}`
///
/// ```
/// meetingProposals/
///   {proposalId}/
///     groupMemberUids: ["uid_A", "uid_B", "uid_C"]
///     startTime:       Timestamp
///     endTime:         Timestamp
///     location:
///       name:      "Cafenea"
///       latitude:  null
///       longitude: null
///     source:          "algorithmic" | "ai"
///     createdAt:       Timestamp
/// ```
/// Whether the proposal was generated algorithmically or by AI.
enum ProposalSource { algorithmic, ai }

class MeetingProposal {
  /// UIDs of all group members this proposal targets.
  final List<String> groupMemberUids;

  /// Where the meeting is proposed to start.
  final DateTime startTime;

  /// Where the meeting is proposed to end.
  final DateTime endTime;

  /// Suggested (or TBD) location for the meeting.
  final MeetingLocation location;

  /// How this proposal was generated.
  final ProposalSource source;

  /// Optional reasoning produced by the AI explaining its choice.
  /// Always `null` for algorithmic proposals.
  final String? aiRationale;

  const MeetingProposal({
    this.groupMemberUids = const [],
    required this.startTime,
    required this.endTime,
    required this.location,
    this.source = ProposalSource.algorithmic,
    this.aiRationale,
  });

  /// Duration of the proposed meeting.
  Duration get duration => endTime.difference(startTime);

  MeetingProposal copyWith({
    List<String>? groupMemberUids,
    DateTime? startTime,
    DateTime? endTime,
    MeetingLocation? location,
    ProposalSource? source,
    String? aiRationale,
  }) {
    return MeetingProposal(
      groupMemberUids: groupMemberUids ?? this.groupMemberUids,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      source: source ?? this.source,
      aiRationale: aiRationale ?? this.aiRationale,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeetingProposal &&
          other.startTime == startTime &&
          other.endTime == endTime &&
          other.location == location;

  @override
  int get hashCode => Object.hash(startTime, endTime, location);

  @override
  String toString() =>
      'MeetingProposal($startTime – $endTime @ ${location.name})';
}

