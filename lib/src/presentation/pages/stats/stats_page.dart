import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/usage_stats_providers.dart';
import 'models/enriched_usage_stats.dart';
import 'widgets/ai_report_sheet.dart';
import 'widgets/app_category_bar.dart';
import 'widgets/completion_overview.dart';
import 'widgets/hero_metrics_row.dart';
import 'widgets/hourly_activity_chart.dart';
import 'widgets/productivity_heatmap.dart';
import 'widgets/stats_constants.dart';
import 'widgets/stats_placeholders.dart';
import 'widgets/stats_toggle.dart';
import 'widgets/task_breakdown_card.dart';
import 'widgets/top_apps_card.dart';
import 'widgets/weekly_pattern_card.dart';

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
      ref.invalidate(enrichedUsageStatsProvider);
      ref.invalidate(taskStatsProvider);
      ref.invalidate(heatmapDataProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissionAsync = ref.watch(hasUsagePermissionProvider);
    final enrichedAsync = ref.watch(enrichedUsageStatsProvider);
    final taskStatsAsync = ref.watch(taskStatsProvider);
    final heatmapAsync = ref.watch(heatmapDataProvider);
    final days = ref.watch(usageStatsDaysProvider);
    final perfectDays = ref.watch(perfectDaysCountProvider);

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

            // Toggle: Today / This Week / This Month
            const StatsToggle(),
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

            // Productivity Heatmap (always visible, 30-day data)
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
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenTimeSection(EnrichedUsageStats enriched, int days) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Feature 1 + 5: Hero metrics row with trend arrows
        HeroMetricsRow(stats: enriched, days: days),
        const SizedBox(height: 16),

        // Feature 2: Annotated hourly chart
        HourlyActivityChart(
          hourly: enriched.hourlyUsage,
          annotations: enriched.hourAnnotations,
          days: days,
        ),
        const SizedBox(height: 16),

        // Feature 3: App category breakdown bar
        AppCategoryBar(
          productiveMinutes: enriched.productiveMinutes,
          distractingMinutes: enriched.distractingMinutes,
          neutralMinutes: enriched.neutralMinutes,
        ),
        const SizedBox(height: 16),

        // Top apps list with category badges
        TopAppsCard(topApps: enriched.topApps),
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
        // Weekly pattern: visible in weekly and monthly modes
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
