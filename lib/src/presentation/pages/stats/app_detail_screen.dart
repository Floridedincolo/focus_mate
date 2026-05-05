import 'dart:convert';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/usage_stats_providers.dart';
import 'models/app_category.dart';
import 'models/enriched_usage_stats.dart';
import 'widgets/stats_constants.dart';

enum _Period { day, week, trend }

class AppDetailScreen extends ConsumerStatefulWidget {
  final AppUsageEntry app;

  const AppDetailScreen({super.key, required this.app});

  @override
  ConsumerState<AppDetailScreen> createState() => _AppDetailScreenState();
}

class _AppDetailScreenState extends ConsumerState<AppDetailScreen> {
  _Period _period = _Period.day;

  int get _days => switch (_period) {
        _Period.day => 1,
        _Period.week => 7,
        _Period.trend => 30,
      };

  @override
  Widget build(BuildContext context) {
    final classifications = ref.watch(appClassificationsProvider);
    final classification = classifications[widget.app.packageName];
    final effectiveCategory = classification?.userCategory ??
        categorizeApp(widget.app.packageName, appName: widget.app.appName);
    final excluded = classification?.excluded ?? false;
    final categoryColor = _colorFor(effectiveCategory);

    final statsAsync = ref.watch(usageStatsForPeriodProvider(_days));

    return Scaffold(
      backgroundColor: kStatsBg,
      appBar: AppBar(
        backgroundColor: kStatsBg,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            _buildAppIcon(widget.app, 32),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.app.appName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodToggle(categoryColor),
            const SizedBox(height: 20),
            statsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                    child: CircularProgressIndicator(color: kStatsAccent)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: $e',
                    style: const TextStyle(color: Colors.white70)),
              ),
              data: (raw) {
                if (raw == null) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Usage permission required.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }
                return _buildChartSection(raw, effectiveCategory);
              },
            ),
            const SizedBox(height: 20),
            _buildAppFeelCard(effectiveCategory, excluded),
            const SizedBox(height: 16),
            _buildExcludeCard(excluded),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodToggle(Color accent) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _toggleButton('Day', _Period.day, accent),
          _toggleButton('Week', _Period.week, accent),
          _toggleButton('Trend', _Period.trend, accent),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, _Period p, Color accent) {
    final selected = _period == p;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _period = p),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _colorFor(AppCategory c) => switch (c) {
        AppCategory.productive => kStatsGreen,
        AppCategory.distracting => kStatsPurple,
        AppCategory.neutral => kStatsBlue,
      };

  Widget _buildChartSection(Map<String, dynamic> raw, AppCategory category) {
    final color = _colorFor(category);
    final pkg = widget.app.packageName;
    if (_period == _Period.day) {
      final hourlyApp = (raw['hourlyAppUsage'] as Map?) ?? const {};
      final list = hourlyApp[pkg];
      final hours = <int>[];
      if (list is List) {
        hours.addAll(list.map((e) => (e as num).toInt()));
      }
      while (hours.length < 24) {
        hours.add(0);
      }
      final total = hours.fold<int>(0, (s, m) => s + m);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroValue('TODAY', formatMinutes(total), 'SCREEN TIME'),
          const SizedBox(height: 16),
          _SingleAppHourlyChart(hourly: hours, color: color),
        ],
      );
    }

    // Week / Trend share daily slice path
    final dailyApp = (raw['dailyAppUsage'] as Map?) ?? const {};
    final list = dailyApp[pkg];
    final daily = <int>[];
    if (list is List) {
      daily.addAll(list.map((e) => (e as num).toInt()));
    }
    final startWeekday = (raw['startWeekday'] as num?)?.toInt() ?? 0;

    if (_period == _Period.week) {
      final total = daily.fold<int>(0, (s, m) => s + m);
      final nonZero = daily.where((d) => d > 0).toList();
      final avg = nonZero.isEmpty
          ? 0
          : (nonZero.fold<int>(0, (a, b) => a + b) ~/ nonZero.length);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroValue('THIS WEEK', formatMinutes(avg), 'AVG. SCREEN TIME',
              extra: 'Total: ${formatMinutes(total)}'),
          const SizedBox(height: 16),
          _SingleAppDailyChart(
              daily: daily, startWeekday: startWeekday, color: color),
        ],
      );
    }

    // Trend
    final firstHalf = daily.length >= 2 ? daily.sublist(0, daily.length ~/ 2) : <int>[];
    final secondHalf = daily.length >= 2 ? daily.sublist(daily.length ~/ 2) : daily;
    int avg(List<int> v) {
      final nz = v.where((d) => d > 0).toList();
      if (nz.isEmpty) return 0;
      return nz.fold<int>(0, (a, b) => a + b) ~/ nz.length;
    }

    final firstAvg = avg(firstHalf);
    final secondAvg = avg(secondHalf);
    final delta = secondAvg - firstAvg;
    final pct = firstAvg > 0 ? (delta * 100 / firstAvg).round() : 0;
    final isUp = delta > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTrendHeader(delta, pct, isUp),
        const SizedBox(height: 16),
        _SingleAppTrendChart(daily: daily, color: color),
      ],
    );
  }

  Widget _buildHeroValue(String label, String value, String sub,
      {String? extra}) {
    return Center(
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                color: kStatsAccent.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              )),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 44,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 4),
          Text(sub,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                letterSpacing: 0.6,
              )),
          if (extra != null) ...[
            const SizedBox(height: 6),
            Text(extra,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildTrendHeader(int delta, int pct, bool isUp) {
    final color = isUp ? kStatsRed : kStatsGreen;
    final sign = isUp ? '+' : '';
    return Center(
      child: Column(
        children: [
          Text('LAST 1 MONTH',
              style: TextStyle(
                color: kStatsAccent.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              )),
          const SizedBox(height: 16),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(
              isUp ? Icons.north_east : Icons.south_east,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text('$sign${formatMinutes(delta.abs())}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${isUp ? '▲' : '▼'} ${pct.abs()}% CHANGE IN THIS PERIOD',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppFeelCard(AppCategory current, bool excluded) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('App Feel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(width: 8),
              Text('This app is for me…',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                  )),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _feelButton(
                  'Distractive', AppCategory.distracting, current, kStatsPurple,
                  enabled: !excluded),
              const SizedBox(width: 10),
              _feelButton(
                  'Neutral', AppCategory.neutral, current, kStatsBlue,
                  enabled: !excluded),
              const SizedBox(width: 10),
              _feelButton(
                  'Productive', AppCategory.productive, current, kStatsGreen,
                  enabled: !excluded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _feelButton(
      String label, AppCategory value, AppCategory current, Color color,
      {required bool enabled}) {
    final selected = value == current;
    final IconData icon = switch (value) {
      AppCategory.distracting => Icons.sentiment_dissatisfied_outlined,
      AppCategory.neutral => Icons.sentiment_neutral_outlined,
      AppCategory.productive => Icons.sentiment_satisfied_outlined,
    };
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: GestureDetector(
          onTap: enabled
              ? () => ref
                  .read(appClassificationsProvider.notifier)
                  .setCategory(widget.app.packageName, value)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: selected ? color : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? color
                    : Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icon,
                    color: selected ? Colors.white : color, size: 26),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExcludeCard(bool excluded) {
    return GestureDetector(
      onTap: () {
        ref
            .read(appClassificationsProvider.notifier)
            .setExcluded(widget.app.packageName, !excluded);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: kStatsCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              excluded ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: excluded ? kStatsRed : Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                excluded ? 'Excluded from stats' : 'Exclude this app',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Switch(
              value: excluded,
              activeColor: kStatsAccent,
              onChanged: (v) => ref
                  .read(appClassificationsProvider.notifier)
                  .setExcluded(widget.app.packageName, v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppIcon(AppUsageEntry app, double size) {
    if (app.iconBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(app.iconBase64);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(bytes,
              width: size, height: size, fit: BoxFit.cover),
        );
      } catch (_) {}
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: kStatsAccent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?',
          style: const TextStyle(
              color: kStatsAccent,
              fontWeight: FontWeight.w700,
              fontSize: 14),
        ),
      ),
    );
  }
}

// ── Per-app charts (single-color, simple) ──

class _SingleAppHourlyChart extends StatelessWidget {
  final List<int> hourly;
  final Color color;
  const _SingleAppHourlyChart({required this.hourly, required this.color});

  @override
  Widget build(BuildContext context) {
    final rawMax = hourly.isEmpty
        ? 1.0
        : hourly.reduce(max).toDouble();
    final maxY = rawMax < 60 ? 60.0 : rawMax;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            barGroups: List.generate(24, (h) {
              final v = hourly[h].toDouble();
              return BarChartGroupData(
                x: h,
                barRods: [
                  BarChartRodData(
                    toY: maxY,
                    width: 6,
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                  BarChartRodData(
                    toY: v,
                    width: 6,
                    color: color,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ],
                barsSpace: -6,
              );
            }),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (v, meta) {
                    String? label;
                    if (v == 0) {
                      label = '0s';
                    } else if (v == 30) {
                      label = '30m';
                    } else if (v == 60) {
                      label = '1h';
                    }
                    if (label == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(label,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 10)),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, meta) {
                    final h = v.toInt();
                    if (h == 0 || h == 6 || h == 12 || h == 18) {
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
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 30,
              getDrawingHorizontalLine: (_) => FlLine(
                color: Colors.white.withValues(alpha: 0.06),
                strokeWidth: 0.5,
              ),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(enabled: false),
          ),
        ),
      ),
    );
  }
}

class _SingleAppDailyChart extends StatelessWidget {
  final List<int> daily;
  final int startWeekday;
  final Color color;
  const _SingleAppDailyChart(
      {required this.daily, required this.startWeekday, required this.color});

  static const _labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    // Map last 7 daily values to weekday positions
    final perWeekday = List<int>.filled(7, 0);
    for (int d = 0; d < daily.length && d < 7; d++) {
      final w = (startWeekday + d) % 7;
      perWeekday[w] = daily[d];
    }

    final rawMax = perWeekday.fold<int>(0, (a, b) => a > b ? a : b).toDouble();
    final maxHours = (rawMax / 60).ceil().clamp(1, 24);
    final maxY = maxHours * 60.0;

    final nz = perWeekday.where((d) => d > 0).toList();
    final avg = nz.isEmpty ? 0.0 : nz.reduce((a, b) => a + b) / nz.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            barGroups: List.generate(7, (w) {
              return BarChartGroupData(
                x: w,
                barRods: [
                  BarChartRodData(
                    toY: maxY,
                    width: 22,
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                  BarChartRodData(
                    toY: perWeekday[w].toDouble(),
                    width: 22,
                    color: color,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ],
                barsSpace: -22,
              );
            }),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: maxY / maxHours,
                  getTitlesWidget: (v, meta) {
                    final h = (v / 60).round();
                    if (h == 0) {
                      return _ax('0s');
                    }
                    if (h == maxHours) return _ax('${h}h');
                    final mid = maxHours ~/ 2;
                    if (mid > 0 && h == mid) return _ax('${h}h');
                    return const SizedBox.shrink();
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i > 6) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_labels[i],
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11)),
                    );
                  },
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / maxHours,
              getDrawingHorizontalLine: (_) => FlLine(
                color: Colors.white.withValues(alpha: 0.06),
                strokeWidth: 0.5,
              ),
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                if (avg > 0)
                  HorizontalLine(
                    y: avg,
                    color: Colors.white.withValues(alpha: 0.3),
                    strokeWidth: 1.2,
                    dashArray: [6, 4],
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
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(enabled: false),
          ),
        ),
      ),
    );
  }

  static Widget _ax(String text) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Text(text,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
      );
}

class _SingleAppTrendChart extends StatelessWidget {
  final List<int> daily;
  final Color color;
  const _SingleAppTrendChart({required this.daily, required this.color});

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) {
      return const SizedBox(height: 200);
    }
    final spots = <FlSpot>[];
    for (int i = 0; i < daily.length; i++) {
      spots.add(FlSpot(i.toDouble(), daily[i].toDouble()));
    }
    final rawMax = daily.reduce(max).toDouble();
    final maxHours = (rawMax / 60).ceil().clamp(1, 24);
    final maxY = maxHours * 60.0;
    final nz = daily.where((d) => d > 0).toList();
    final avg =
        nz.isEmpty ? 0.0 : nz.fold<int>(0, (a, b) => a + b) / nz.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY,
            minX: 0,
            maxX: (daily.length - 1).toDouble().clamp(1, double.infinity),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / maxHours,
              getDrawingHorizontalLine: (_) => FlLine(
                color: Colors.white.withValues(alpha: 0.06),
                strokeWidth: 0.5,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: maxY / maxHours,
                  getTitlesWidget: (v, meta) {
                    final h = (v / 60).round();
                    if (h == 0) {
                      return _SingleAppDailyChart._ax('0s');
                    }
                    if (h == maxHours) {
                      return _SingleAppDailyChart._ax('${h}h');
                    }
                    final mid = maxHours ~/ 2;
                    if (mid > 0 && h == mid) {
                      return _SingleAppDailyChart._ax('${h}h');
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.4,
                color: color,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: color.withValues(alpha: 0.1),
                ),
              ),
            ],
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                if (avg > 0)
                  HorizontalLine(
                    y: avg,
                    color: Colors.white.withValues(alpha: 0.3),
                    strokeWidth: 1.2,
                    dashArray: [6, 4],
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
            lineTouchData: const LineTouchData(enabled: false),
          ),
        ),
      ),
    );
  }
}
