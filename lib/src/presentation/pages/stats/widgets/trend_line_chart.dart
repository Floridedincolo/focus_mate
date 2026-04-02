import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'stats_constants.dart';

/// Trend view: line chart of daily screen time over 1M/3M/Max.
/// Shows an AVG dashed line across the chart.
/// Skips days with zero data (app not installed yet).
class TrendLineChart extends StatelessWidget {
  final List<int> dailyUsage; // minutes per day, index 0 = oldest
  final int trendDays; // 30, 90, 365
  final DateTime periodStart;

  const TrendLineChart({
    super.key,
    required this.dailyUsage,
    required this.trendDays,
    required this.periodStart,
  });

  @override
  Widget build(BuildContext context) {
    if (dailyUsage.isEmpty) return const SizedBox.shrink();

    // Find the first day with actual data (> 0) to skip the no-data prefix
    int firstDataIdx = 0;
    for (int i = 0; i < dailyUsage.length; i++) {
      if (dailyUsage[i] > 0) {
        firstDataIdx = i;
        break;
      }
    }

    // Build spots only from the first day with data
    final spots = <FlSpot>[];
    for (int i = firstDataIdx; i < dailyUsage.length; i++) {
      spots.add(FlSpot(i.toDouble(), dailyUsage[i].toDouble()));
    }
    if (spots.isEmpty) return const SizedBox.shrink();

    // AVG only counts non-zero days
    final nonZeroDays = dailyUsage.where((d) => d > 0).toList();
    final avg = nonZeroDays.isEmpty
        ? 0.0
        : nonZeroDays.fold(0, (a, b) => a + b) / nonZeroDays.length;

    final maxVal = dailyUsage.reduce(max).toDouble();
    final maxHours = ((maxVal / 60).ceil()).clamp(1, 24);
    final maxY = maxHours * 60.0;

    // Pre-compute month label positions: center of each month's visible range
    final monthLabels = _computeMonthLabels(firstDataIdx);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                minX: firstDataIdx.toDouble(),
                maxX: (dailyUsage.length - 1).toDouble().clamp(1, double.infinity),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / maxHours,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.06),
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: maxY / maxHours,
                      getTitlesWidget: (value, meta) {
                        final hours = (value / 60).round();
                        if (hours == 0) return _axisLabel('0s');
                        if (hours == maxHours) return _axisLabel('${hours}h');
                        final mid = maxHours ~/ 2;
                        if (mid > 0 && hours == mid) {
                          return _axisLabel('${hours}h');
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        // Show label only at pre-computed month center positions
                        final label = monthLabels[idx];
                        if (label != null) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Main line — smoother curve
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.45,
                    color: kStatsAccent,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: kStatsAccent.withValues(alpha: 0.08),
                    ),
                  ),
                ],
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: avg,
                      color: Colors.white.withValues(alpha: 0.3),
                      strokeWidth: 1.5,
                      dashArray: [8, 6],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 4, bottom: 2),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        labelResolver: (_) => 'AVG',
                      ),
                    ),
                  ],
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => kStatsCard,
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final date = periodStart.add(
                            Duration(days: spot.x.toInt()));
                        return LineTooltipItem(
                          '${formatMinutes(spot.y.toInt())}\n${DateFormat('MMM d').format(date)}',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compute centered month labels.
  /// Returns a map: dayIndex -> "MMM" label, placed at the center of each month's range.
  Map<int, String> _computeMonthLabels(int firstDataIdx) {
    final labels = <int, String>{};
    if (dailyUsage.isEmpty) return labels;

    // Group day indices by (year, month)
    int? currentMonth;
    int? currentYear;
    int monthStart = firstDataIdx;

    for (int i = firstDataIdx; i <= dailyUsage.length; i++) {
      final date = periodStart.add(Duration(days: i));
      final isLast = i == dailyUsage.length;

      if (isLast || (currentMonth != null && (date.month != currentMonth || date.year != currentYear))) {
        // End of a month segment — place label at center
        final monthEnd = i - 1;
        final center = ((monthStart + monthEnd) / 2).round();
        final labelDate = periodStart.add(Duration(days: monthStart));
        labels[center] = DateFormat('MMM').format(labelDate);

        monthStart = i;
      }

      if (!isLast) {
        currentMonth = date.month;
        currentYear = date.year;
      }
    }

    return labels;
  }

  Widget _axisLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(text,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35), fontSize: 10)),
    );
  }
}
