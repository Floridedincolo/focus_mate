import 'package:flutter/material.dart';
import '../../../providers/usage_stats_providers.dart';
import 'stats_constants.dart';

/// Completion overview card with circular progress ring and mini pills.
class CompletionOverview extends StatelessWidget {
  final TaskStatsData stats;
  final int days;

  const CompletionOverview({
    super.key,
    required this.stats,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (stats.completionRate * 100).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: stats.completionRate,
                    strokeWidth: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(kStatsGreen),
                  ),
                ),
                Text(
                  '$pct%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${stats.completed} of ${stats.total} tasks',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  days == 1
                      ? 'completed today'
                      : days == 7
                          ? 'completed this week'
                          : 'completed this month',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MiniPill(
                      icon: Icons.local_fire_department,
                      label: '${stats.bestStreak}',
                      color: Colors.orangeAccent,
                    ),
                    if (stats.missed > 0)
                      _MiniPill(
                        icon: Icons.close,
                        label: '${stats.missed} missed',
                        color: Colors.redAccent,
                      ),
                    if (stats.perfectDays > 0)
                      _MiniPill(
                        icon: Icons.star,
                        label: '${stats.perfectDays} perfect',
                        color: kStatsGreen,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MiniPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
