import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/member_proposal_detail.dart';
import '../../../domain/entities/meeting_proposal.dart';

/// Participant colours, cycled when there are more members than entries.
const _kParticipantColors = [
  Colors.blueAccent,
  Colors.greenAccent,
  Colors.pinkAccent,
  Colors.amberAccent,
  Colors.cyanAccent,
  Colors.purpleAccent,
  Colors.tealAccent,
  Colors.orangeAccent,
];

/// Card that displays a single [MeetingProposal].
class MeetingProposalCard extends StatelessWidget {
  final MeetingProposal proposal;
  final int index;

  const MeetingProposalCard({
    super.key,
    required this.proposal,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm');
    final dateFmt = DateFormat('EEE, d MMM');
    final start = timeFmt.format(proposal.startTime);
    final end = timeFmt.format(proposal.endTime);
    final date = dateFmt.format(proposal.startTime);
    final isAi = proposal.source == ProposalSource.ai;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        date,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$start – $end',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAi
                        ? Colors.purpleAccent.withValues(alpha: 0.15)
                        : Colors.tealAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isAi ? 'AI' : 'Algorithm',
                    style: TextStyle(
                      color: isAi ? Colors.purpleAccent : Colors.tealAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Location ────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.place, color: Colors.white38, size: 18),
                const SizedBox(width: 6),
                Text(
                  proposal.location.name,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),

            // ── Algorithmic Member Details ───────────────────────────
            if (proposal.memberDetails.isNotEmpty) ...[
              const SizedBox(height: 14),
              _MemberGapTimeline(details: proposal.memberDetails),
              const SizedBox(height: 12),
              _TransitBreakdown(details: proposal.memberDetails),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Gap Timeline ────────────────────────────────────────────────────────────

class _MemberGapTimeline extends StatelessWidget {
  final List<MemberProposalDetail> details;
  const _MemberGapTimeline({required this.details});

  @override
  Widget build(BuildContext context) {
    // Find the earliest gap start and latest gap end for the visual scale.
    int earliest = details.first.gapStartMin;
    int latest = details.first.gapEndMin;
    for (final d in details) {
      if (d.gapStartMin < earliest) earliest = d.gapStartMin;
      if (d.gapEndMin > latest) latest = d.gapEndMin;
    }
    final range = (latest - earliest).clamp(1, 1440);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < details.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _TimelineRow(
              detail: details[i],
              color: _kParticipantColors[i % _kParticipantColors.length],
              earliest: earliest,
              range: range,
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final MemberProposalDetail detail;
  final Color color;
  final int earliest;
  final int range;

  const _TimelineRow({
    required this.detail,
    required this.color,
    required this.earliest,
    required this.range,
  });

  @override
  Widget build(BuildContext context) {
    // Fraction positions within the overall time range.
    final startFrac =
        ((detail.gapStartMin - earliest) / range).clamp(0.0, 1.0);
    final endFrac = ((detail.gapEndMin - earliest) / range).clamp(0.0, 1.0);
    final barFrac = (endFrac - startFrac).clamp(0.01, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label + duration
        Row(
          children: [
            Icon(Icons.person, size: 12, color: color),
            const SizedBox(width: 6),
            Text(
              detail.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const Spacer(),
            Text(
              '${detail.gapStartFmt} – ${detail.gapEndFmt}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${detail.gapDurationMin}min',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Visual bar
        SizedBox(
          height: 6,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              return Stack(
                children: [
                  // Track
                  Container(
                    width: totalWidth,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  // Filled portion
                  Positioned(
                    left: startFrac * totalWidth,
                    child: Container(
                      width: barFrac * totalWidth,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Transit Breakdown ───────────────────────────────────────────────────────

class _TransitBreakdown extends StatelessWidget {
  final List<MemberProposalDetail> details;
  const _TransitBreakdown({required this.details});

  @override
  Widget build(BuildContext context) {
    // Only show if at least one member has transit data.
    final hasAnyTransit =
        details.any((d) => d.transitToMin != null || d.transitFromMin != null);
    if (!hasAnyTransit) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(
            children: [
              Icon(Icons.directions_car, size: 14, color: Colors.amber),
              SizedBox(width: 8),
              Text(
                'Transit Time',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // To venue
          _TransitDirection(
            icon: Icons.arrow_forward,
            label: 'To venue',
            details: details,
            getMinutes: (d) => d.transitToMin,
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 8),

          // From venue
          _TransitDirection(
            icon: Icons.arrow_back,
            label: 'From venue',
            details: details,
            getMinutes: (d) => d.transitFromMin,
          ),
        ],
      ),
    );
  }
}

class _TransitDirection extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<MemberProposalDetail> details;
  final int? Function(MemberProposalDetail) getMinutes;

  const _TransitDirection({
    required this.icon,
    required this.label,
    required this.details,
    required this.getMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: Colors.white54),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 0; i < details.length; i++)
              _TransitBadge(
                label: details[i].label,
                minutes: getMinutes(details[i]),
                color: _kParticipantColors[i % _kParticipantColors.length],
              ),
          ],
        ),
      ],
    );
  }
}

class _TransitBadge extends StatelessWidget {
  final String label;
  final int? minutes;
  final Color color;

  const _TransitBadge({
    required this.label,
    required this.minutes,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            minutes != null ? '${minutes}min' : '–',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
