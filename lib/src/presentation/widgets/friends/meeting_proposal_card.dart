import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/meeting_proposal.dart';

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

            // ── AI Rationale ────────────────────────────────────────
            if (proposal.aiRationale != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: Colors.purpleAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        proposal.aiRationale!,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
