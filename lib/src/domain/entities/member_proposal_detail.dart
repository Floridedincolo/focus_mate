/// Per-member breakdown of gap times and transit for a meeting proposal.
class MemberProposalDetail {
  /// Display label (e.g. "You", "Alex").
  final String label;

  /// Index into the participant list (0 = current user).
  final int memberIndex;

  /// Start of this member's free gap (minutes since midnight).
  final int gapStartMin;

  /// End of this member's free gap (minutes since midnight).
  final int gapEndMin;

  /// Minutes of travel from last task/home to the meeting venue (null = unknown).
  final int? transitToMin;

  /// Minutes of travel from the meeting venue to next task/home (null = unknown).
  final int? transitFromMin;

  const MemberProposalDetail({
    required this.label,
    required this.memberIndex,
    required this.gapStartMin,
    required this.gapEndMin,
    this.transitToMin,
    this.transitFromMin,
  });

  int get gapDurationMin => gapEndMin - gapStartMin;

  String get gapStartFmt =>
      '${(gapStartMin ~/ 60).toString().padLeft(2, '0')}:'
      '${(gapStartMin % 60).toString().padLeft(2, '0')}';

  String get gapEndFmt =>
      '${(gapEndMin ~/ 60).toString().padLeft(2, '0')}:'
      '${(gapEndMin % 60).toString().padLeft(2, '0')}';
}
