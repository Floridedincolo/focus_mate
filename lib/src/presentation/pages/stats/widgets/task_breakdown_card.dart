import 'package:flutter/material.dart';
import '../../../../domain/entities/task_completion_status.dart';
import '../../../providers/usage_stats_providers.dart';
import 'stats_constants.dart';

/// Per-task list with status dots, time slots, and streak indicators.
class TaskBreakdownCard extends StatelessWidget {
  final TaskStatsData stats;

  const TaskBreakdownCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.perTask.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Task Breakdown',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),
          ...stats.perTask.map((entry) {
            final dotColor = switch (entry.status) {
              TaskCompletionStatus.completed => kStatsGreen,
              TaskCompletionStatus.missed => Colors.redAccent,
              _ => Colors.white38,
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: dotColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (entry.timeSlot.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(entry.timeSlot,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 11)),
                        ],
                      ],
                    ),
                  ),
                  if (entry.streak > 0) ...[
                    Icon(Icons.local_fire_department,
                        size: 14,
                        color: Colors.orangeAccent.withValues(alpha: 0.8)),
                    const SizedBox(width: 3),
                    Text('${entry.streak}',
                        style: TextStyle(
                            color:
                                Colors.orangeAccent.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
