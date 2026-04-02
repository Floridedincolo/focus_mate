import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/enriched_usage_stats.dart';
import 'stats_constants.dart';

/// Weekly/monthly stacked bar chart showing per-day screen time
/// split by app category (productive/distracting/neutral).
///
/// For 7 days: one bar per day (Mon-Sun).
/// For 30 days: aggregated into 7 weekday bars (Mon-Sun averaged).
class DailyActivityChart extends StatelessWidget {
  final List<int> dailyUsage;
  final List<DayCategoryBreakdown> dailyBreakdown;
  final int startWeekday; // 0=Mon..6=Sun
  final int days;
  final int? selectedDay;
  final ValueChanged<int?>? onDaySelected;

  const DailyActivityChart({
    super.key,
    required this.dailyUsage,
    required this.dailyBreakdown,
    required this.startWeekday,
    required this.days,
    this.selectedDay,
    this.onDaySelected,
  });

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _bgBarColor = Color(0xFF2A2A2A);

  @override
  Widget build(BuildContext context) {
    final bars = _computeBars();
    final maxVal = bars.isEmpty
        ? 1.0
        : bars.map((b) => b.total).reduce((a, b) => a > b ? a : b).toDouble();
    // Round max up to nearest hour for nice Y-axis
    final maxHours = (maxVal / 60).ceil().clamp(1, 24);
    final maxY = maxHours * 60.0;

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
              days <= 7 ? 'Daily Activity' : 'Avg. Daily Activity',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barGroups: List.generate(7, (i) => _buildBarGroup(i, bars, maxY)),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: maxY / maxHours, // one label per hour mark
                      getTitlesWidget: (value, meta) {
                        final hours = (value / 60).round();
                        if (hours == 0) return _axisLabel('0s');
                        if (hours == maxHours) return _axisLabel('${hours}h');
                        // Show middle label
                        final mid = maxHours ~/ 2;
                        if (mid > 0 && hours == mid) return _axisLabel('${hours}h');
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
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i > 6) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _dayLabels[i],
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                              fontWeight: selectedDay == i
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / maxHours,
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
                      final day = response.spot!.touchedBarGroupIndex;
                      onDaySelected?.call(
                        selectedDay == day ? null : day,
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
          // Average line label
          _buildAvgLabel(bars),
          const SizedBox(height: 8),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _axisLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(text,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35), fontSize: 10)),
    );
  }

  /// For 7 days: direct map. For 30 days: average into weekday buckets.
  List<_BarData> _computeBars() {
    if (dailyBreakdown.isEmpty) {
      return List.generate(7, (_) => const _BarData());
    }

    if (days <= 7) {
      // Direct: map day index to weekday
      final result = List.generate(7, (_) => const _BarData());
      for (int d = 0; d < dailyBreakdown.length && d < days; d++) {
        final weekday = (startWeekday + d) % 7;
        final b = dailyBreakdown[d];
        result[weekday] = _BarData(
          total: b.totalMinutes,
          productive: b.productiveMinutes,
          distracting: b.distractingMinutes,
          neutral: b.neutralMinutes,
        );
      }
      return result;
    }

    // Monthly: average by weekday
    final totals = List.generate(7, (_) => <int>[0, 0, 0, 0]); // [total, prod, dist, neut]
    final counts = List<int>.filled(7, 0);
    for (int d = 0; d < dailyBreakdown.length; d++) {
      final weekday = (startWeekday + d) % 7;
      final b = dailyBreakdown[d];
      totals[weekday][0] += b.totalMinutes;
      totals[weekday][1] += b.productiveMinutes;
      totals[weekday][2] += b.distractingMinutes;
      totals[weekday][3] += b.neutralMinutes;
      counts[weekday]++;
    }
    return List.generate(7, (w) {
      final c = counts[w] > 0 ? counts[w] : 1;
      return _BarData(
        total: totals[w][0] ~/ c,
        productive: totals[w][1] ~/ c,
        distracting: totals[w][2] ~/ c,
        neutral: totals[w][3] ~/ c,
      );
    });
  }

  BarChartGroupData _buildBarGroup(int weekday, List<_BarData> bars, double maxY) {
    final data = weekday < bars.length ? bars[weekday] : const _BarData();
    final isSelected = selectedDay == weekday;
    final total = data.total.toDouble();

    final bgRod = BarChartRodData(
      toY: maxY,
      width: 28,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
      color: isSelected
          ? _bgBarColor.withValues(alpha: 0.8)
          : _bgBarColor.withValues(alpha: 0.5),
    );

    final BarChartRodData fgRod;
    if (total == 0) {
      fgRod = BarChartRodData(toY: 0, width: 28, color: Colors.transparent);
    } else {
      final prod = data.productive.toDouble();
      final dist = data.distracting.toDouble();
      final neut = data.neutral.toDouble();
      final catTotal = prod + dist + neut;
      final scale = catTotal > 0 ? total / catTotal : 1.0;

      final stackItems = <BarChartRodStackItem>[];
      double y = 0;
      final sp = prod * scale;
      final sn = neut * scale;
      final sd = dist * scale;

      if (sp > 0) {
        stackItems.add(BarChartRodStackItem(y, y + sp, kStatsGreen));
        y += sp;
      }
      if (sn > 0) {
        stackItems.add(BarChartRodStackItem(y, y + sn, kStatsBlue));
        y += sn;
      }
      if (sd > 0) {
        stackItems.add(BarChartRodStackItem(y, y + sd, kStatsPurple));
        y += sd;
      }

      if (stackItems.isEmpty) {
        fgRod = BarChartRodData(
          toY: total,
          width: 28,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          color: kStatsBlue,
        );
      } else {
        fgRod = BarChartRodData(
          toY: y,
          width: 28,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          rodStackItems: stackItems,
          color: Colors.transparent,
        );
      }
    }

    return BarChartGroupData(
      x: weekday,
      barRods: [bgRod, fgRod],
      barsSpace: -28,
    );
  }

  Widget _buildAvgLabel(List<_BarData> bars) {
    final nonZero = bars.where((b) => b.total > 0).toList();
    if (nonZero.isEmpty) return const SizedBox.shrink();
    final avg = nonZero.fold(0, (s, b) => s + b.total) ~/ nonZero.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 20,
          height: 1.5,
          color: Colors.white.withValues(alpha: 0.3),
        ),
        const SizedBox(width: 6),
        Text(
          'AVG ${formatMinutes(avg)}/day',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendDot(kStatsGreen, 'Productive'),
        const SizedBox(width: 14),
        _legendDot(kStatsPurple, 'Distracting'),
        const SizedBox(width: 14),
        _legendDot(kStatsBlue, 'Neutral'),
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

class _BarData {
  final int total;
  final int productive;
  final int distracting;
  final int neutral;

  const _BarData({
    this.total = 0,
    this.productive = 0,
    this.distracting = 0,
    this.neutral = 0,
  });
}
