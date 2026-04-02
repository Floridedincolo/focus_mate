import 'dart:math';
import 'package:flutter/material.dart';
import 'stats_constants.dart';

/// "Your screen time has increased/decreased" comparison card.
/// Compares first-half avg vs second-half avg of the period,
/// with mini daily bar charts for each half.
class TrendComparisonCard extends StatelessWidget {
  final int firstHalfAvg;       // minutes per day
  final int secondHalfAvg;      // minutes per day
  final List<int> firstHalfDays;  // daily values for first half
  final List<int> secondHalfDays; // daily values for second half

  const TrendComparisonCard({
    super.key,
    required this.firstHalfAvg,
    required this.secondHalfAvg,
    required this.firstHalfDays,
    required this.secondHalfDays,
  });

  @override
  Widget build(BuildContext context) {
    final delta = secondHalfAvg - firstHalfAvg;
    final increased = delta > 0;
    final deltaAbs = delta.abs();

    if (firstHalfAvg == 0 && secondHalfAvg == 0) return const SizedBox.shrink();

    // Don't show misleading comparison when there's no previous data
    final hasPreviousData = firstHalfDays.any((d) => d > 0);

    // Find global max for consistent bar scaling
    final allVals = [...firstHalfDays, ...secondHalfDays];
    final globalMax = allVals.isEmpty ? 1 : allVals.reduce(max).clamp(1, 999999);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            !hasPreviousData
                ? 'Your weekly screen time'
                : increased
                    ? 'Your screen time has increased'
                    : 'Your screen time has decreased',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            !hasPreviousData
                ? 'Not enough history for comparison yet.'
                : 'Last week, your screen time is '
                  '${increased ? 'up' : 'down'} by '
                  '${formatMinutes(deltaAbs)} a day.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          // Comparison columns with mini bars
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _HalfColumn(
                  avgLabel: formatMinutes(firstHalfAvg),
                  avgColor: Colors.white,
                  barColor: Colors.white.withValues(alpha: 0.3),
                  periodLabel: 'First week avg.',
                  dailyValues: firstHalfDays,
                  globalMax: globalMax,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HalfColumn(
                  avgLabel: formatMinutes(secondHalfAvg),
                  avgColor: increased ? kStatsRed : kStatsGreen,
                  barColor: increased ? kStatsRed : kStatsGreen,
                  periodLabel: 'Last week avg.',
                  dailyValues: secondHalfDays,
                  globalMax: globalMax,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HalfColumn extends StatelessWidget {
  final String avgLabel;
  final Color avgColor;
  final Color barColor;
  final String periodLabel;
  final List<int> dailyValues;
  final int globalMax;

  const _HalfColumn({
    required this.avgLabel,
    required this.avgColor,
    required this.barColor,
    required this.periodLabel,
    required this.dailyValues,
    required this.globalMax,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          avgLabel,
          style: TextStyle(
            color: avgColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        // Avg line
        Container(
          height: 3,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(height: 6),
        // Mini daily bars
        SizedBox(
          height: 40,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _buildMiniBars(),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          periodLabel,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMiniBars() {
    if (dailyValues.isEmpty) return [const SizedBox.shrink()];

    return dailyValues.asMap().entries.map((entry) {
      final value = entry.value;
      final fraction = (value / globalMax).clamp(0.0, 1.0);
      final barHeight = max(2.0, fraction * 36.0);

      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0.5),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: barHeight,
              decoration: BoxDecoration(
                color: barColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}
