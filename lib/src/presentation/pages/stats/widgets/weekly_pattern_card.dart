import 'package:flutter/material.dart';
import 'stats_constants.dart';

/// Weekly consistency card with 7-column bars (Mon-Sun).
class WeeklyPatternCard extends StatelessWidget {
  final List<double> dailyRates;

  const WeeklyPatternCard({super.key, required this.dailyRates});

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekly Consistency',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final rate = dailyRates[i];
              final barColor = rate > 0.7
                  ? kStatsGreen
                  : rate > 0.3
                      ? Colors.orangeAccent
                      : rate > 0
                          ? Colors.redAccent
                          : Colors.white.withValues(alpha: 0.08);
              return Column(
                children: [
                  Container(
                    width: 28,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.bottomCenter,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 28,
                      height: rate > 0 ? (rate * 60).clamp(6.0, 60.0) : 4,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(dayLabels[i],
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
