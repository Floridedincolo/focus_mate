import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../domain/entities/task_completion_status.dart';
import '../providers/usage_stats_providers.dart';

const _kBg = Color(0xFF0D0D0D);
const _kCard = Color(0xFF1A1A1A);
const _kAccent = Color(0xFF6366F1);
const _kAccent2 = Color(0xFF8B5CF6);
const _kGreen = Color(0xFF34D399);

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(hasUsagePermissionProvider);
      ref.invalidate(usageStatsProvider);
      ref.invalidate(taskStatsProvider);
    }
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final permissionAsync = ref.watch(hasUsagePermissionProvider);
    final statsAsync = ref.watch(usageStatsProvider);
    final taskStatsAsync = ref.watch(taskStatsProvider);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Statistics',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Permission banner
            permissionAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (hasPermission) {
                if (hasPermission) return const SizedBox.shrink();
                return _buildPermissionBanner();
              },
            ),

            // Toggle
            _buildToggle(),
            const SizedBox(height: 20),

            // Screen time stats
            statsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: CircularProgressIndicator(color: _kAccent),
                ),
              ),
              error: (e, _) => _buildErrorCard(e),
              data: (data) {
                if (data == null) return _buildNoPermissionPlaceholder();
                return _buildDashboardContent(data);
              },
            ),

            const SizedBox(height: 20),

            // Task stats section (always visible)
            taskStatsAsync.when(
              loading: () => _buildTaskStatsLoading(),
              error: (_, __) => const SizedBox.shrink(),
              data: (stats) => _buildTaskStatsSection(stats),
            ),

            const SizedBox(height: 20),

            // AI Report button
            _buildAiReportButton(statsAsync, taskStatsAsync),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Permission Banner ──

  Widget _buildPermissionBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orangeAccent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Usage Data Access',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enable permission to see your screen time stats.',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              ref.read(usageStatsDsProvider).requestUsagePermission();
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.orangeAccent.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Enable',
              style: TextStyle(
                  color: Colors.orangeAccent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Toggle ──

  Widget _buildToggle() {
    final days = ref.watch(usageStatsDaysProvider);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildToggleItem('Today', 1, days),
          _buildToggleItem('This Week', 7, days),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String label, int days, int currentDays) {
    final isSelected = currentDays == days;
    return Expanded(
      child: GestureDetector(
        onTap: () =>
            ref.read(usageStatsDaysProvider.notifier).state = days,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _kAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white54,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  // ── Screen Time Dashboard ──

  Widget _buildDashboardContent(Map<String, dynamic> data) {
    final totalMinutes =
        (data['totalScreenTimeMinutes'] as num?)?.toInt() ?? 0;
    final hourlyRaw = data['hourlyUsage'] as List<dynamic>? ?? [];
    final hourly = hourlyRaw.map((e) => (e as num).toInt()).toList();
    while (hourly.length < 24) {
      hourly.add(0);
    }
    final topApps = (data['topApps'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroMetric(totalMinutes),
        const SizedBox(height: 20),
        _buildHourlyChart(hourly),
        const SizedBox(height: 20),
        if (topApps.isNotEmpty) _buildTopApps(topApps, totalMinutes),
      ],
    );
  }

  Widget _buildHeroMetric(int totalMinutes) {
    final days = ref.watch(usageStatsDaysProvider);
    final subtitle =
        days == 1 ? 'Screen time today' : 'Screen time this week';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            _formatMinutes(totalMinutes),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyChart(List<int> hourly) {
    final maxVal = hourly.reduce((a, b) => a > b ? a : b).toDouble();
    final maxY = maxVal < 1 ? 1.0 : maxVal;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 16),
            child: Text(
              ref.watch(usageStatsDaysProvider) == 1
                  ? 'Hourly Activity'
                  : 'Avg. Hourly Activity',
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
                        gradient: const LinearGradient(
                          colors: [_kAccent, _kAccent2],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ],
                  );
                }),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
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
                                    color:
                                        Colors.white.withValues(alpha: 0.4),
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
                    getTooltipColor: (_) => _kAccent,
                    getTooltipItem: (group, gi, rod, ri) {
                      return BarTooltipItem(
                        '${_formatMinutes(rod.toY.toInt())}\n${group.x}:00',
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
        ],
      ),
    );
  }

  // ── Top Apps ──

  Widget _buildTopApps(List<Map<String, dynamic>> topApps, int totalMinutes) {
    final maxMinutes = topApps.isNotEmpty
        ? (topApps.first['usageMinutes'] as num?)?.toInt() ?? 1
        : 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Most Used Apps',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          ...topApps.map((app) {
            final appName = app['appName'] as String? ??
                app['packageName'] as String? ??
                '?';
            final minutes = (app['usageMinutes'] as num?)?.toInt() ?? 0;
            final fraction = maxMinutes > 0 ? minutes / maxMinutes : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  _buildAppIcon(app, appName),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(appName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: fraction.clamp(0.0, 1.0),
                            minHeight: 4,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.06),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                _kAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(_formatMinutes(minutes),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAppIcon(Map<String, dynamic> app, String appName) {
    final iconBase64 = app['iconBase64'] as String?;
    if (iconBase64 != null && iconBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(iconBase64);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(bytes,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallbackIcon(appName)),
        );
      } catch (_) {
        return _buildFallbackIcon(appName);
      }
    }
    return _buildFallbackIcon(appName);
  }

  Widget _buildFallbackIcon(String appName) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          appName.isNotEmpty ? appName[0].toUpperCase() : '?',
          style: const TextStyle(
              color: _kAccent, fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }

  // ── Task Stats Section ──

  Widget _buildTaskStatsLoading() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(20)),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
              color: _kGreen, strokeWidth: 3),
        ),
      ),
    );
  }

  Widget _buildTaskStatsSection(TaskStatsData stats) {
    final days = ref.watch(usageStatsDaysProvider);
    return Column(
      children: [
        // Card 1: Completion Overview
        _buildCompletionOverview(stats, days),
        const SizedBox(height: 16),
        // Card 2: Task Breakdown
        if (stats.perTask.isNotEmpty) ...[
          _buildTaskBreakdown(stats),
          const SizedBox(height: 16),
        ],
        // Card 3: Weekly Pattern (only in weekly mode)
        if (days == 7) _buildWeeklyPattern(stats.dailyRates),
      ],
    );
  }

  Widget _buildCompletionOverview(TaskStatsData stats, int days) {
    final pct = (stats.completionRate * 100).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          // Big circular progress
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
                        const AlwaysStoppedAnimation<Color>(_kGreen),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$pct%',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Stats
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
                  days == 1 ? 'completed today' : 'completed this week',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildMiniPill(
                      Icons.local_fire_department,
                      '${stats.bestStreak}',
                      Colors.orangeAccent,
                    ),
                    const SizedBox(width: 8),
                    if (stats.missed > 0)
                      _buildMiniPill(
                        Icons.close,
                        '${stats.missed} missed',
                        Colors.redAccent,
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

  Widget _buildMiniPill(IconData icon, String label, Color color) {
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

  Widget _buildTaskBreakdown(TaskStatsData stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(20)),
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
              TaskCompletionStatus.completed => _kGreen,
              TaskCompletionStatus.missed => Colors.redAccent,
              _ => Colors.white38,
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  // Status dot
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: dotColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  // Title + time slot
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
                                  color:
                                      Colors.white.withValues(alpha: 0.4),
                                  fontSize: 11)),
                        ],
                      ],
                    ),
                  ),
                  // Streak
                  if (entry.streak > 0) ...[
                    Icon(Icons.local_fire_department,
                        size: 14, color: Colors.orangeAccent.withValues(alpha: 0.8)),
                    const SizedBox(width: 3),
                    Text('${entry.streak}',
                        style: TextStyle(
                            color: Colors.orangeAccent.withValues(alpha: 0.8),
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

  Widget _buildWeeklyPattern(List<double> dailyRates) {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(20)),
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
                  ? _kGreen
                  : rate > 0.3
                      ? Colors.orangeAccent
                      : rate > 0
                          ? Colors.redAccent
                          : Colors.white.withValues(alpha: 0.08);
              return Column(
                children: [
                  // Bar
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

  // ── AI Report ──

  Widget _buildAiReportButton(
    AsyncValue<Map<String, dynamic>?> statsAsync,
    AsyncValue<TaskStatsData> taskStatsAsync,
  ) {
    return GestureDetector(
      onTap: () => _showAiReport(statsAsync, taskStatsAsync),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_kAccent, _kAccent2]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('Generate AI Report',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _showAiReport(
    AsyncValue<Map<String, dynamic>?> statsAsync,
    AsyncValue<TaskStatsData> taskStatsAsync,
  ) async {
    // Show bottom sheet immediately with loading state
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiReportSheet(
        screenTimeData: statsAsync.valueOrNull,
        taskStats: taskStatsAsync.valueOrNull ?? TaskStatsData.empty,
        formatMinutes: _formatMinutes,
      ),
    );
  }

  // ── Error / Placeholder ──

  Widget _buildErrorCard(Object error) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
          const SizedBox(height: 12),
          Text('Failed to load data',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => ref.invalidate(usageStatsProvider),
            child: const Text('Retry', style: TextStyle(color: _kAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPermissionPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Icon(Icons.bar_chart_rounded,
              size: 56, color: _kAccent.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('Enable usage data access\nto see your statistics.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                  height: 1.5)),
        ],
      ),
    );
  }
}

// ── AI Report Bottom Sheet (StatefulWidget for async Gemini call) ──

class _AiReportSheet extends StatefulWidget {
  final Map<String, dynamic>? screenTimeData;
  final TaskStatsData taskStats;
  final String Function(int) formatMinutes;

  const _AiReportSheet({
    required this.screenTimeData,
    required this.taskStats,
    required this.formatMinutes,
  });

  @override
  State<_AiReportSheet> createState() => _AiReportSheetState();
}

class _AiReportSheetState extends State<_AiReportSheet> {
  bool _loading = true;
  String? _error;
  int _score = 0;
  String _summary = '';
  List<String> _insights = [];
  List<String> _tips = [];

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  Future<void> _generateReport() async {
    try {
      final prompt = _buildPrompt();
      final model = FirebaseAI.vertexAI().generativeModel(
        model: 'gemini-2.0-flash',
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.4,
        ),
      );

      final response = await model
          .generateContent([Content.text(prompt)]).timeout(
              const Duration(seconds: 30));

      final text = response.text ?? '';
      final json = jsonDecode(text) as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _score = (json['score'] as num?)?.toInt() ?? 5;
          _summary = json['summary'] as String? ?? '';
          _insights = (json['insights'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          _tips = (json['tips'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not generate report. Please try again.';
          _loading = false;
        });
      }
    }
  }

  String _buildPrompt() {
    final buf = StringBuffer();
    buf.writeln(
        'You are a digital wellbeing coach. Analyze this user\'s data and provide actionable insights.');
    buf.writeln('');

    final data = widget.screenTimeData;
    if (data != null) {
      final total = (data['totalScreenTimeMinutes'] as num?)?.toInt() ?? 0;
      buf.writeln('SCREEN TIME:');
      buf.writeln('- Total: ${widget.formatMinutes(total)}');
      final topApps = data['topApps'] as List<dynamic>? ?? [];
      if (topApps.isNotEmpty) {
        buf.writeln('- Top apps:');
        for (final app in topApps.take(5)) {
          final a = app as Map;
          buf.writeln(
              '  * ${a['appName']}: ${widget.formatMinutes((a['usageMinutes'] as num?)?.toInt() ?? 0)}');
        }
      }
      final hourly = (data['hourlyUsage'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList();
      if (hourly != null) {
        int peakHour = 0;
        for (int i = 1; i < hourly.length; i++) {
          if (hourly[i] > hourly[peakHour]) peakHour = i;
        }
        buf.writeln('- Peak usage hour: $peakHour:00');
      }
    }

    buf.writeln('');
    buf.writeln('TASKS:');
    buf.writeln(
        '- Completed: ${widget.taskStats.completed} / ${widget.taskStats.total}');
    buf.writeln('- Missed: ${widget.taskStats.missed}');
    buf.writeln('- Best streak: ${widget.taskStats.bestStreak} days');
    buf.writeln(
        '- Completion rate: ${(widget.taskStats.completionRate * 100).round()}%');

    if (widget.taskStats.perTask.isNotEmpty) {
      buf.writeln('- Per-task breakdown:');
      for (final t in widget.taskStats.perTask) {
        buf.writeln(
            '  * "${t.title}" — ${t.status.name}, streak: ${t.streak}${t.timeSlot.isNotEmpty ? ', time: ${t.timeSlot}' : ''}');
      }
    }

    buf.writeln('');
    buf.writeln('Respond in this exact JSON format:');
    buf.writeln('{');
    buf.writeln(
        '  "score": <1-10 integer, overall productivity/wellbeing score>,');
    buf.writeln('  "summary": "<one sentence overall assessment>",');
    buf.writeln(
        '  "insights": ["<insight 1>", "<insight 2>", "<insight 3>"],');
    buf.writeln(
        '  "tips": ["<actionable tip 1>", "<actionable tip 2>"]');
    buf.writeln('}');
    buf.writeln('');
    buf.writeln(
        'Keep insights short (1 sentence each). Tips should be specific and actionable. Be encouraging but honest.');

    return buf.toString();
  }

  Color _scoreColor(int score) {
    if (score >= 7) return _kGreen;
    if (score >= 4) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: _kAccent, size: 22),
                  SizedBox(width: 8),
                  Text('AI Wellbeing Report',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 24),

              if (_loading) ...[
                const SizedBox(height: 40),
                const Center(
                    child: CircularProgressIndicator(color: _kAccent)),
                const SizedBox(height: 16),
                Center(
                  child: Text('Analyzing your data...',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14)),
                ),
                const SizedBox(height: 40),
              ] else if (_error != null) ...[
                const SizedBox(height: 20),
                Icon(Icons.cloud_off,
                    size: 48,
                    color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14)),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                      _generateReport();
                    },
                    child:
                        const Text('Retry', style: TextStyle(color: _kAccent)),
                  ),
                ),
              ] else ...[
                // Score
                Center(
                  child: Column(
                    children: [
                      Text('$_score',
                          style: TextStyle(
                              color: _scoreColor(_score),
                              fontSize: 56,
                              fontWeight: FontWeight.w800)),
                      Text('/ 10',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_summary.isNotEmpty)
                  Center(
                    child: Text(_summary,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                            height: 1.4)),
                  ),
                const SizedBox(height: 24),

                // Insights
                if (_insights.isNotEmpty) ...[
                  Text('Insights',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1)),
                  const SizedBox(height: 10),
                  ...(_insights.map((insight) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.lightbulb_outline,
                                  size: 16, color: _kAccent),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(insight,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      height: 1.4)),
                            ),
                          ],
                        ),
                      ))),
                  const SizedBox(height: 16),
                ],

                // Tips
                if (_tips.isNotEmpty) ...[
                  Text('Tips',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1)),
                  const SizedBox(height: 10),
                  ...(_tips.map((tip) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _kAccent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _kAccent.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.tips_and_updates,
                                size: 16, color: _kAccent2),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(tip,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      height: 1.4)),
                            ),
                          ],
                        ),
                      ))),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}
