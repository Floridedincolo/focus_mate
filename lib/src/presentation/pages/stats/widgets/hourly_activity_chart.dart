import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/hour_annotation.dart';
import 'stats_constants.dart';

/// Hybrid hourly activity chart with stacked bars over grey background.
///
/// Every hour shows a grey background bar (capacity = 60 min). Colored
/// stacked segments fill from the bottom:
/// - **Green** = productive apps
/// - **Purple** = distracting apps
/// - **Blue** = neutral apps
/// - **Red** (offline focus mode) = entire bar is red
///
/// Right Y-axis shows 0s / 30m / 1h. Tapping a bar notifies the parent
/// via [onHourSelected].
class HourlyActivityChart extends StatelessWidget {
  final List<int> hourly;
  final List<HourAnnotation> annotations;
  final int days;
  final int? selectedHour;
  final ValueChanged<int?>? onHourSelected;

  const HourlyActivityChart({
    super.key,
    required this.hourly,
    required this.annotations,
    required this.days,
    this.selectedHour,
    this.onHourSelected,
  });

  static const greenColor = kStatsGreen;
  static const redColor = kStatsRed;
  static const purpleColor = kStatsPurple;
  static const blueColor = kStatsBlue;
  static const _bgBarColor = Color(0xFF2A2A2A);

  @override
  Widget build(BuildContext context) {
    final rawMax = hourly.isEmpty
        ? 1.0
        : hourly.reduce((a, b) => a > b ? a : b).toDouble();
    final maxY = rawMax < 60 ? 60.0 : rawMax;

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
            height: 190,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barGroups: List.generate(24, (i) => _buildBarGroup(i, maxY)),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        String? label;
                        if (value == 0) {
                          label = '0s';
                        } else if (value == 30) {
                          label = '30m';
                        } else if (value == 60) {
                          label = '1h';
                        }
                        if (label == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final h = value.toInt();
                        if (h == 0 || h == 6 || h == 12 || h == 18) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '$h',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 11,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 30,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.06),
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchCallback: (event, response) {
                    if (event is FlTapUpEvent &&
                        response != null &&
                        response.spot != null) {
                      final hour = response.spot!.touchedBarGroupIndex;
                      onHourSelected?.call(
                        selectedHour == hour ? null : hour,
                      );
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    tooltipPadding: EdgeInsets.zero,
                    tooltipMargin: 0,
                    getTooltipColor: (_) => Colors.transparent,
                    getTooltipItem: (group, gi, rod, ri) => null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildLegend(),
        ],
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int hour, double maxY) {
    final totalMinutes = hourly[hour].toDouble();
    final isSelected = selectedHour == hour;

    final bgRod = BarChartRodData(
      toY: maxY,
      width: 8,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      color: isSelected
          ? _bgBarColor.withValues(alpha: 0.8)
          : _bgBarColor.withValues(alpha: 0.5),
    );

    final BarChartRodData fgRod;

    if (hour >= annotations.length || totalMinutes == 0) {
      fgRod = BarChartRodData(
        toY: 0,
        width: 8,
        color: Colors.transparent,
      );
    } else {
      final ann = annotations[hour];

      if (ann.mode == HourMode.offline) {
        fgRod = BarChartRodData(
          toY: totalMinutes,
          width: 8,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          color: redColor,
        );
      } else {
        final prod = ann.productiveMinutes.toDouble();
        final dist = ann.distractingMinutes.toDouble();
        final neut = ann.neutralMinutes.toDouble();
        final categoryTotal = prod + dist + neut;

        final scale =
            categoryTotal > 0 ? totalMinutes / categoryTotal : 1.0;
        final scaledProd = prod * scale;
        final scaledNeut = neut * scale;
        final scaledDist = dist * scale;

        final stackItems = <BarChartRodStackItem>[];
        double y = 0;

        if (scaledProd > 0) {
          stackItems
              .add(BarChartRodStackItem(y, y + scaledProd, greenColor));
          y += scaledProd;
        }
        if (scaledNeut > 0) {
          stackItems
              .add(BarChartRodStackItem(y, y + scaledNeut, blueColor));
          y += scaledNeut;
        }
        if (scaledDist > 0) {
          stackItems
              .add(BarChartRodStackItem(y, y + scaledDist, purpleColor));
          y += scaledDist;
        }

        if (stackItems.isEmpty) {
          fgRod = BarChartRodData(
            toY: totalMinutes,
            width: 8,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
            color: blueColor,
          );
        } else {
          fgRod = BarChartRodData(
            toY: y,
            width: 8,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
            rodStackItems: stackItems,
            color: Colors.transparent,
          );
        }
      }
    }

    return BarChartGroupData(
      x: hour,
      barRods: [bgRod, fgRod],
      barsSpace: -8,
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendDot(greenColor, 'Productive'),
        const SizedBox(width: 14),
        _legendDot(purpleColor, 'Distracting'),
        const SizedBox(width: 14),
        _legendDot(blueColor, 'Neutral'),
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
