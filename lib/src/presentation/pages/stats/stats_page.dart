import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- Adăugat importul aici

import '../../providers/usage_stats_providers.dart';
import 'models/app_category.dart';
import 'models/enriched_usage_stats.dart';
import 'widgets/ai_report_sheet.dart';
import 'widgets/app_category_bar.dart';
import 'widgets/completion_overview.dart';
import 'widgets/hero_metrics_row.dart';
import 'widgets/daily_activity_chart.dart';
import 'widgets/hourly_activity_chart.dart';
import 'widgets/productivity_heatmap.dart';
import 'widgets/stats_constants.dart';
import 'widgets/stats_placeholders.dart';
import 'widgets/stats_toggle.dart';
import 'widgets/task_breakdown_card.dart';
import 'widgets/top_apps_card.dart';
import 'widgets/trend_app_changes_card.dart';
import 'widgets/trend_comparison_card.dart';
import 'widgets/trend_line_chart.dart';
import 'widgets/trend_sub_toggle.dart';
import 'widgets/weekly_pattern_card.dart';

// --- PROVIDER NOU PENTRU DISTRAGERI PREVENITE ---
final preventedDistractionsProvider = FutureProvider.autoDispose.family<int, (int days, int offset)>((ref, params) async {
  final days = params.$1;
  final offset = params.$2;
  final prefs = await SharedPreferences.getInstance();
  int total = 0;

  // Data de bază (poate fi azi, ieri, etc. în funcție de săgețile de navigare)
  final baseDate = DateTime.now().add(Duration(days: offset));

  if (days == 1) {
    // Pentru o singură zi
    final dateStr = DateFormat('yyyy-MM-dd').format(baseDate);
    // Kotlin a salvat cu "flutter_", dar plugin-ul SharedPreferences din Flutter
    // cere/adaugă el automat prefixul ăsta "sub capotă".
    return prefs.getInt('prevented_distractions_$dateStr') ?? 0;
  } else {
    // Pentru 7 sau 30 de zile (Facem suma pe zilele respective)
    for (int i = 0; i < days; i++) {
      final d = baseDate.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      total += prefs.getInt('prevented_distractions_$dateStr') ?? 0;
    }
    return total;
  }
});
// -------------------------------------------------

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage>
    with WidgetsBindingObserver {
  int? _selectedHour; // for daily (hourly bars) view
  int? _selectedDay;  // for weekly/monthly (daily bars) view

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
      ref.invalidate(enrichedUsageStatsProvider);
      ref.invalidate(taskStatsProvider);
      ref.invalidate(heatmapDataProvider);
      // Invalidate și providerul nou ca să facem refresh la distrageri prevenite
      ref.invalidate(preventedDistractionsProvider);
    }
  }

  void _onHourSelected(int? hour) {
    setState(() => _selectedHour = hour);
  }

  void _onDaySelected(int? day) {
    setState(() => _selectedDay = day);
  }

  void _clearSelections() {
    setState(() {
      _selectedHour = null;
      _selectedDay = null;
    });
  }

  DateTime _getSelectedDate() {
    final offset = ref.read(dateOffsetProvider);
    return DateTime.now().add(Duration(days: offset));
  }

  void _goToPreviousDay() {
    ref.read(dateOffsetProvider.notifier).state--;
    _clearSelections();
  }

  void _goToNextDay() {
    final current = ref.read(dateOffsetProvider);
    if (current >= 0) return;
    ref.read(dateOffsetProvider.notifier).state++;
    _clearSelections();
  }

  /// Build per-hour app list from hourlyAppUsage when an hour is selected.
  List<AppUsageEntry> _buildHourApps(EnrichedUsageStats enriched, int hour) {
    final entries = <AppUsageEntry>[];

    for (final e in enriched.hourlyAppUsage.entries) {
      final pkg = e.key;
      final minutesThisHour = e.value[hour];
      if (minutesThisHour <= 0) continue;

      // Try to find app name/icon from the global top apps list
      final match = enriched.topApps.where((a) => a.packageName == pkg);
      final appName = match.isNotEmpty ? match.first.appName : pkg;
      final iconBase64 = match.isNotEmpty ? match.first.iconBase64 : '';

      entries.add(AppUsageEntry(
        packageName: pkg,
        appName: appName,
        usageMinutes: minutesThisHour,
        iconBase64: iconBase64,
        category: categorizeApp(pkg, appName: appName),
      ));
    }

    entries.sort((a, b) => b.usageMinutes.compareTo(a.usageMinutes));
    return entries;
  }

  /// Build per-day app list from dailyAppUsage.
  /// [dayIndex] is the raw index in the dailyUsage array.
  List<AppUsageEntry> _buildDayApps(EnrichedUsageStats enriched, int dayIndex) {
    final entries = <AppUsageEntry>[];
    for (final e in enriched.dailyAppUsage.entries) {
      final pkg = e.key;
      if (dayIndex >= e.value.length) continue;
      final min = e.value[dayIndex];
      if (min <= 0) continue;

      final match = enriched.topApps.where((a) => a.packageName == pkg);
      final appName = match.isNotEmpty ? match.first.appName : pkg;
      final iconBase64 = match.isNotEmpty ? match.first.iconBase64 : '';

      entries.add(AppUsageEntry(
        packageName: pkg,
        appName: appName,
        usageMinutes: min,
        iconBase64: iconBase64,
        category: categorizeApp(pkg, appName: appName),
      ));
    }
    entries.sort((a, b) => b.usageMinutes.compareTo(a.usageMinutes));
    return entries;
  }

  /// Convert a selected weekday (0=Mon) back to a raw daily index
  /// for accessing dailyUsage/dailyAppUsage arrays.
  /// Returns null if no matching day or if it's a monthly average.
  int? _weekdayToDayIndex(EnrichedUsageStats enriched, int weekday, int days) {
    if (days > 7) return null; // monthly is averaged, no single day
    for (int d = 0; d < enriched.dailyUsage.length && d < days; d++) {
      final wd = (enriched.startWeekday + d) % 7;
      if (wd == weekday) return d;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final permissionAsync = ref.watch(hasUsagePermissionProvider);
    final enrichedAsync = ref.watch(enrichedUsageStatsProvider);
    final taskStatsAsync = ref.watch(taskStatsProvider);
    final heatmapAsync = ref.watch(heatmapDataProvider);
    final days = ref.watch(usageStatsDaysProvider);
    final perfectDays = ref.watch(perfectDaysCountProvider);
    final dateOffset = ref.watch(dateOffsetProvider);
    final isTrend = ref.watch(isTrendModeProvider);

    return Scaffold(
      backgroundColor: kStatsBg,
      appBar: AppBar(
        backgroundColor: kStatsBg,
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
                return const StatsPermissionBanner();
              },
            ),

            // Toggle: Day / Week / Trend
            const StatsToggle(),
            const SizedBox(height: 16),

            if (isTrend)
            // ── TREND VIEW ──
              enrichedAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: CircularProgressIndicator(color: kStatsAccent),
                  ),
                ),
                error: (e, _) => StatsErrorCard(error: e),
                data: (enriched) {
                  if (enriched == null) {
                    return const StatsNoPermissionPlaceholder();
                  }
                  return _buildTrendView(enriched, days);
                },
              )
            else ...[
              // ── DAY / WEEK VIEW ──
              // Date navigation header
              _buildDateHeader(days, dateOffset),
              const SizedBox(height: 20),

              // Screen time section
              enrichedAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: CircularProgressIndicator(color: kStatsAccent),
                  ),
                ),
                error: (e, _) => StatsErrorCard(error: e),
                data: (enriched) {
                  if (enriched == null) {
                    return const StatsNoPermissionPlaceholder();
                  }
                  return _buildScreenTimeSection(enriched, days);
                },
              ),

              const SizedBox(height: 20),

              // Task stats section
              taskStatsAsync.when(
                loading: () => const TaskStatsLoading(),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) => _buildTaskStatsSection(stats, days),
              ),

              const SizedBox(height: 20),

              // Productivity Heatmap
              heatmapAsync.when(
                loading: () => const TaskStatsLoading(),
                error: (_, __) => const SizedBox.shrink(),
                data: (data) {
                  if (data.isEmpty) return const SizedBox.shrink();
                  return ProductivityHeatmap(
                      data: data, perfectDays: perfectDays);
                },
              ),

              const SizedBox(height: 20),

              // AI Report button
              _buildAiReportButton(enrichedAsync, taskStatsAsync, perfectDays),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(int days, int dateOffset) {
    final selectedDate = _getSelectedDate();
    final isToday = dateOffset == 0;
    final canGoForward = dateOffset < 0;

    String dateLabel;
    if (days == 1) {
      if (isToday) {
        dateLabel = 'Today, ${DateFormat('MMMM d').format(selectedDate)}'.toUpperCase();
      } else if (dateOffset == -1) {
        dateLabel = 'Yesterday, ${DateFormat('MMMM d').format(selectedDate)}'.toUpperCase();
      } else {
        dateLabel = DateFormat('EEEE, MMMM d').format(selectedDate).toUpperCase();
      }
    } else if (days == 7) {
      final start = selectedDate.subtract(Duration(days: 6));
      dateLabel = '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d').format(selectedDate)}'.toUpperCase();
    } else {
      final start = selectedDate.subtract(Duration(days: 29));
      dateLabel = '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d').format(selectedDate)}'.toUpperCase();
    }

    // Selected hour/day subtitle
    String? selectionSubtitle;
    if (_selectedHour != null && days == 1) {
      final h = _selectedHour!;
      selectionSubtitle =
      '${h.toString().padLeft(2, '0')}:00 – ${(h + 1).toString().padLeft(2, '0')}:00';
    } else if (_selectedDay != null && days > 1) {
      const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      selectionSubtitle = dayNames[_selectedDay!];
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: _goToPreviousDay,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kStatsCard,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_left,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 20,
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    dateLabel,
                    style: TextStyle(
                      color: kStatsAccent.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (selectionSubtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      selectionSubtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: canGoForward ? _goToNextDay : null,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kStatsCard,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right,
                  color: canGoForward
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.15),
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrendView(EnrichedUsageStats enriched, int days) {
    final trendDays = ref.watch(trendPeriodProvider);
    final daily = enriched.dailyUsage;
    final now = DateTime.now();
    final periodStart = now.subtract(Duration(days: daily.length - 1));

    // Period label
    String periodLabel;
    if (trendDays == 30) {
      periodLabel = 'LAST 1 MONTH';
    } else if (trendDays == 90) {
      periodLabel = 'LAST 3 MONTHS';
    } else {
      periodLabel = 'ALL TIME';
    }

    // Filter out zero-data days (app wasn't installed/running)
    int avgNonZero(List<int> days) {
      final valid = days.where((d) => d > 0).toList();
      if (valid.isEmpty) return 0;
      return valid.fold(0, (a, b) => a + b) ~/ valid.length;
    }

    // Fixed-period comparison: last 7 days vs previous 7 days
    final bool hasFullHistory = daily.length >= 14 &&
        daily.sublist(0, daily.length - 7).any((d) => d > 0);

    List<int> lastWeek;
    List<int> prevWeek;

    if (hasFullHistory) {
      lastWeek = daily.sublist(daily.length - 7);
      prevWeek = daily.sublist(daily.length - 14, daily.length - 7);
    } else {
      // Split non-zero days in half for a meaningful comparison
      final validDays = daily.where((d) => d > 0).toList();
      if (validDays.length >= 2) {
        final mid = validDays.length ~/ 2;
        prevWeek = validDays.sublist(0, mid);
        lastWeek = validDays.sublist(mid);
      } else {
        prevWeek = <int>[];
        lastWeek = daily;
      }
    }

    final lastWeekAvg = avgNonZero(lastWeek);
    final prevWeekAvg = avgNonZero(prevWeek);

    // Compute per-app deltas
    final appDeltas = <String, int>{}; // packageName -> delta minutes/day
    final appNames = <String, String>{};
    final appIcons = <String, String>{};
    for (final app in enriched.topApps) {
      appNames[app.packageName] = app.appName;
      appIcons[app.packageName] = app.iconBase64;
    }

    final bool hasEnoughHistory = daily.length >= 14 &&
        daily.sublist(0, daily.length - 7).any((d) => d > 0);

    for (final entry in enriched.dailyAppUsage.entries) {
      final pkg = entry.key;
      final perDay = entry.value;
      final nonZeroDays = perDay.where((d) => d > 0).length;
      if (nonZeroDays < 2) continue;

      List<int> recentPart;
      List<int> olderPart;

      if (hasEnoughHistory) {
        recentPart = perDay.length >= 7
            ? perDay.sublist(perDay.length - 7)
            : perDay;
        olderPart = perDay.length >= 14
            ? perDay.sublist(perDay.length - 14, perDay.length - 7)
            : perDay.sublist(0, perDay.length - 7);
      } else {
        final validIndices = <int>[];
        for (int i = 0; i < perDay.length; i++) {
          if (perDay[i] > 0) validIndices.add(i);
        }
        if (validIndices.length < 2) continue;
        final mid = validIndices.length ~/ 2;
        olderPart = validIndices.sublist(0, mid).map((i) => perDay[i]).toList();
        recentPart = validIndices.sublist(mid).map((i) => perDay[i]).toList();
      }

      final firstAvg = avgNonZero(olderPart);
      final secondAvg = avgNonZero(recentPart);
      final delta = secondAvg - firstAvg;
      if (delta != 0) appDeltas[pkg] = delta;
    }

    // Top time-savers (biggest decrease)
    final decreased = appDeltas.entries
        .where((e) => e.value < 0)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final topSavers = decreased.take(3).map((e) => AppTrendEntry(
      appName: appNames[e.key] ?? e.key,
      iconBase64: appIcons[e.key] ?? '',
      deltaMinutes: e.value,
    )).toList();

    // Top increase (biggest increase)
    final increased = appDeltas.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topIncrease = increased.take(3).map((e) => AppTrendEntry(
      appName: appNames[e.key] ?? e.key,
      iconBase64: appIcons[e.key] ?? '',
      deltaMinutes: e.value,
    )).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Period label
        Center(
          child: Text(
            periodLabel,
            style: TextStyle(
              color: kStatsAccent.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Line chart
        TrendLineChart(
          dailyUsage: daily,
          trendDays: trendDays,
          periodStart: periodStart,
        ),
        const SizedBox(height: 16),

        // Sub-toggle: 1M / 3M / Max
        const TrendSubToggle(),
        const SizedBox(height: 16),

        // Comparison card
        TrendComparisonCard(
          firstHalfAvg: prevWeekAvg,
          secondHalfAvg: lastWeekAvg,
          firstHalfDays: prevWeek,
          secondHalfDays: lastWeek,
        ),
        const SizedBox(height: 16),

        if (topSavers.isNotEmpty)
          TopTimeSaversCard(entries: topSavers),
        if (topSavers.isNotEmpty)
          const SizedBox(height: 16),

        if (topIncrease.isNotEmpty)
          TopIncreaseCard(entries: topIncrease),
        if (topIncrease.isNotEmpty)
          const SizedBox(height: 16),

        TopAppsCard(topApps: enriched.topApps),
        const SizedBox(height: 16),

        AppCategoryBar(
          productiveMinutes: enriched.productiveMinutes,
          distractingMinutes: enriched.distractingMinutes,
          neutralMinutes: enriched.neutralMinutes,
        ),
      ],
    );
  }

  // --- WIDGET NOU PENTRU AFIȘAREA DISTRAGERILOR PREVENITE ---
  Widget _buildPreventedDistractionsCard(int days, int dateOffset) {
    // Apelăm providerul cu argumentele de zi curentă și offset
    final preventedAsync = ref.watch(preventedDistractionsProvider((days, dateOffset)));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kStatsCard, // Folosește variabila ta de culoare
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.orangeAccent,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Distractions Prevented",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                preventedAsync.when(
                  data: (count) => Text(
                    '$count times',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  loading: () => const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(color: Colors.orangeAccent, strokeWidth: 2),
                  ),
                  error: (_, __) => const Text('0 times', style: TextStyle(color: Colors.white, fontSize: 22)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenTimeSection(EnrichedUsageStats enriched, int days) {
    // Determine which apps / category breakdown to display based on selection
    List<AppUsageEntry> displayApps;
    int displayProd, displayDist, displayNeut;
    int? heroSelectedHour;

    if (days == 1) {
      heroSelectedHour = _selectedHour;

      if (_selectedHour != null) {
        displayApps = _buildHourApps(enriched, _selectedHour!);
        final ann = _selectedHour! < enriched.hourAnnotations.length
            ? enriched.hourAnnotations[_selectedHour!]
            : null;
        displayProd = ann?.productiveMinutes ?? 0;
        displayDist = ann?.distractingMinutes ?? 0;
        displayNeut = ann?.neutralMinutes ?? 0;
      } else {
        displayApps = enriched.topApps;
        displayProd = enriched.productiveMinutes;
        displayDist = enriched.distractingMinutes;
        displayNeut = enriched.neutralMinutes;
      }
    } else {
      heroSelectedHour = null;

      if (_selectedDay != null) {
        final dayIdx = _weekdayToDayIndex(enriched, _selectedDay!, days);
        if (dayIdx != null) {
          displayApps = _buildDayApps(enriched, dayIdx);
          final b = dayIdx < enriched.dailyCategoryBreakdown.length
              ? enriched.dailyCategoryBreakdown[dayIdx]
              : null;
          displayProd = b?.productiveMinutes ?? 0;
          displayDist = b?.distractingMinutes ?? 0;
          displayNeut = b?.neutralMinutes ?? 0;
        } else {
          displayApps = enriched.topApps;
          displayProd = enriched.productiveMinutes;
          displayDist = enriched.distractingMinutes;
          displayNeut = enriched.neutralMinutes;
        }
      } else {
        displayApps = enriched.topApps;
        displayProd = enriched.productiveMinutes;
        displayDist = enriched.distractingMinutes;
        displayNeut = enriched.neutralMinutes;
      }
    }

    // Compute screen time for hero card
    int? heroScreenTimeOverride;
    if (days == 1 && _selectedHour != null) {
      heroScreenTimeOverride = enriched.hourlyUsage[_selectedHour!];
    } else if (days > 1 && _selectedDay != null) {
      final dayIdx = _weekdayToDayIndex(enriched, _selectedDay!, days);
      if (dayIdx != null && dayIdx < enriched.dailyUsage.length) {
        heroScreenTimeOverride = enriched.dailyUsage[dayIdx];
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero metrics row
        HeroMetricsRow(
          stats: enriched,
          days: days,
          selectedHour: heroSelectedHour,
          selectedScreenTimeOverride: heroScreenTimeOverride,
        ),

        const SizedBox(height: 16),

        // Chart: hourly for daily view, daily for weekly/monthly
        if (days == 1)
          HourlyActivityChart(
            hourly: enriched.hourlyUsage,
            annotations: enriched.hourAnnotations,
            days: days,
            selectedHour: _selectedHour,
            onHourSelected: _onHourSelected,
          )
        else
          DailyActivityChart(
            dailyUsage: enriched.dailyUsage,
            dailyBreakdown: enriched.dailyCategoryBreakdown,
            startWeekday: enriched.startWeekday,
            days: days,
            selectedDay: _selectedDay,
            onDaySelected: _onDaySelected,
          ),
        const SizedBox(height: 16),

        // Category breakdown bar
        AppCategoryBar(
          productiveMinutes: displayProd,
          distractingMinutes: displayDist,
          neutralMinutes: displayNeut,
        ),
        const SizedBox(height: 16),

        // Top apps (filtered by selection)
        TopAppsCard(topApps: displayApps),
      ],
    );
  }

  Widget _buildTaskStatsSection(TaskStatsData stats, int days) {
    return Column(
      children: [
        CompletionOverview(stats: stats, days: days),
        const SizedBox(height: 16),
        if (stats.perTask.isNotEmpty) ...[
          TaskBreakdownCard(stats: stats),
          const SizedBox(height: 16),
        ],
        if (days >= 7) WeeklyPatternCard(dailyRates: stats.dailyRates),
      ],
    );
  }

  Widget _buildAiReportButton(
      AsyncValue<EnrichedUsageStats?> enrichedAsync,
      AsyncValue<TaskStatsData> taskStatsAsync,
      int perfectDays,
      ) {
    return GestureDetector(
      onTap: () => _showAiReport(enrichedAsync, taskStatsAsync, perfectDays),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [kStatsAccent, kStatsAccent2]),
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
      AsyncValue<EnrichedUsageStats?> enrichedAsync,
      AsyncValue<TaskStatsData> taskStatsAsync,
      int perfectDays,
      ) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiReportSheet(
        enrichedStats: enrichedAsync.valueOrNull,
        taskStats: taskStatsAsync.valueOrNull ?? TaskStatsData.empty,
        perfectDays: perfectDays,
      ),
    );
  }
}