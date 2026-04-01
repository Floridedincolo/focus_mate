import 'package:flutter/material.dart';
import 'stats_constants.dart';

/// Feature 3: Split progress bar showing Productive / Distracting / Neutral
/// screen time breakdown by app category.
class AppCategoryBar extends StatelessWidget {
  final int productiveMinutes;
  final int distractingMinutes;
  final int neutralMinutes;

  const AppCategoryBar({
    super.key,
    required this.productiveMinutes,
    required this.distractingMinutes,
    required this.neutralMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final total = productiveMinutes + distractingMinutes + neutralMinutes;
    if (total == 0) return const SizedBox.shrink();

    final pPct = productiveMinutes / total;
    final dPct = distractingMinutes / total;
    final nPct = neutralMinutes / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Screen Time Breakdown',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),
          // Split bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (pPct > 0)
                    Expanded(
                      flex: (pPct * 1000).round(),
                      child: Container(color: kStatsGreen),
                    ),
                  if (dPct > 0)
                    Expanded(
                      flex: (dPct * 1000).round(),
                      child: Container(color: kStatsRed),
                    ),
                  if (nPct > 0)
                    Expanded(
                      flex: (nPct * 1000).round(),
                      child: Container(color: Colors.white24),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Labels
          Row(
            children: [
              _CategoryLabel(
                color: kStatsGreen,
                label: 'Productive',
                minutes: productiveMinutes,
                pct: pPct,
              ),
              const Spacer(),
              _CategoryLabel(
                color: kStatsRed,
                label: 'Distracting',
                minutes: distractingMinutes,
                pct: dPct,
              ),
              const Spacer(),
              _CategoryLabel(
                color: Colors.white24,
                label: 'Neutral',
                minutes: neutralMinutes,
                pct: nPct,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryLabel extends StatelessWidget {
  final Color color;
  final String label;
  final int minutes;
  final double pct;

  const _CategoryLabel({
    required this.color,
    required this.label,
    required this.minutes,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
            Text(
              '${formatMinutes(minutes)} (${(pct * 100).round()}%)',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }
}
