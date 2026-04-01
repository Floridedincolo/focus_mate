import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/hour_annotation.dart';
import 'stats_constants.dart';

/// Feature 2: Hourly activity bar chart with task-correlation coloring.
/// Green = focused during task hour (low screen time),
/// Red = distracted during task hour (high screen time),
/// Accent = general (no task scheduled).
class HourlyActivityChart extends StatelessWidget {
  final List<int> hourly;
  final List<HourAnnotation> annotations;
  final int days;

  const HourlyActivityChart({
    super.key,
    required this.hourly,
    required this.annotations,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = hourly.isEmpty
        ? 1.0
        : hourly.reduce((a, b) => a > b ? a : b).toDouble();
    final maxY = maxVal < 1 ? 1.0 : maxVal;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 16),
            child: Text(
              days == 1 ? 'Hourly Activity' : 'Avg. Hourly Activity',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barGroups: List.generate(24, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: hourly[i].toDouble(),
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        gradient: _gradientForHour(i),
                      ),
                    ],
                  );
                }),
                titlesData: FlTitlesData(
                  leftTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final h = value.toInt();
                        if (h == 0 || h == 6 || h == 12 || h == 18 || h == 23) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('$h',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 11)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => kStatsAccent,
                    getTooltipItem: (group, gi, rod, ri) {
                      return BarTooltipItem(
                        '${formatMinutes(rod.toY.toInt())}\n${group.x}:00',
                        const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          _buildLegend(),
        ],
      ),
    );
  }

  LinearGradient _gradientForHour(int hour) {
    if (hour < annotations.length) {
      final ann = annotations[hour];
      if (ann.hasTask) {
        if (ann.screenTimeLevel == ScreenTimeLevel.high) {
          // Red: distracted during task
          return const LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFFF87171)],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          );
        } else if (ann.screenTimeLevel == ScreenTimeLevel.low) {
          // Green: focused during task
          return const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF34D399)],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          );
        }
      }
    }
    // Default accent gradient
    return const LinearGradient(
      colors: [kStatsAccent, kStatsAccent2],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendDot(kStatsGreen, 'Focused'),
        const SizedBox(width: 16),
        _legendDot(const Color(0xFFEF4444), 'Distracted'),
        const SizedBox(width: 16),
        _legendDot(kStatsAccent, 'General'),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
      ],
    );
  }
}
