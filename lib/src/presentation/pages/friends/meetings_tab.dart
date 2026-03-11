import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/friend_providers.dart';
import '../../widgets/friends/meeting_proposal_card.dart';
import 'plan_meeting_page.dart';

/// Tab showing the user's saved meeting proposals and a button to plan new ones.
class MeetingsTab extends ConsumerWidget {
  const MeetingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proposalsAsync = ref.watch(watchMeetingProposalsProvider);

    return proposalsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (e, _) => Center(
        child:
            Text('Error: $e', style: const TextStyle(color: Colors.redAccent)),
      ),
      data: (proposals) {
        final now = DateTime.now();
        final upcoming = proposals
            .where((p) => p.endTime.isAfter(now))
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
        final past = proposals
            .where((p) => p.endTime.isBefore(now) || p.endTime.isAtSameMomentAs(now))
            .toList()
          ..sort((a, b) => b.startTime.compareTo(a.startTime));

        return CustomScrollView(
          slivers: [
            // ── Plan Meeting button ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PlanMeetingPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'Plan a Meeting',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Empty state ──────────────────────────────────────────
            if (proposals.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_available,
                            color: Colors.white24, size: 64),
                        SizedBox(height: 16),
                        Text(
                          'No meetings yet',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Plan a meeting with your friends to get started',
                          style:
                              TextStyle(color: Colors.white24, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Upcoming section ─────────────────────────────────────
            if (upcoming.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: _SectionHeader(title: 'Upcoming'),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => MeetingProposalCard(
                    proposal: upcoming[i],
                    index: i,
                  ),
                  childCount: upcoming.length,
                ),
              ),
            ],

            // ── Past section ─────────────────────────────────────────
            if (past.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: _SectionHeader(title: 'Past'),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Opacity(
                    opacity: 0.5,
                    child: MeetingProposalCard(
                      proposal: past[i],
                      index: i,
                    ),
                  ),
                  childCount: past.length,
                ),
              ),
            ],

            // Bottom padding
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

