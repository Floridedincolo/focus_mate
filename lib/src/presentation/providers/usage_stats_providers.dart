import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/service_locator.dart';
import '../../data/datasources/usage_stats_datasource.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_completion_status.dart';
import '../../domain/entities/repeat_type.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/usecases/compute_task_status.dart';
import '../../domain/usecases/task_occurrence.dart';
import '../pages/stats/models/app_category.dart';
import '../pages/stats/models/daily_completion.dart';
import '../pages/stats/models/enriched_usage_stats.dart';
import '../pages/stats/models/hour_annotation.dart';
import 'task_providers.dart';

// ── Core datasource providers ──

final usageStatsDsProvider = Provider<UsageStatsDataSource>(
  (ref) => getIt<UsageStatsDataSource>(),
);

final hasUsagePermissionProvider = FutureProvider<bool>((ref) async {
  final ds = ref.watch(usageStatsDsProvider);
  return ds.hasUsagePermission();
});

/// Selected number of days: 1 = Today, 7 = This Week, 30 = This Month
final usageStatsDaysProvider = StateProvider<int>((ref) => 1);

final usageStatsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final hasPermission = await ref.watch(hasUsagePermissionProvider.future);
  if (!hasPermission) return null;
  final ds = ref.watch(usageStatsDsProvider);
  final days = ref.watch(usageStatsDaysProvider);
  return ds.getUsageStats(days: days);
});

// ── Rich Task Stats ──

class TaskStatusEntry {
  final String title;
  final TaskCompletionStatus status;
  final int streak;
  final String timeSlot;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  const TaskStatusEntry({
    required this.title,
    required this.status,
    required this.streak,
    required this.timeSlot,
    this.startTime,
    this.endTime,
  });
}

class TaskStatsData {
  final int completed;
  final int total;
  final int missed;
  final int bestStreak;
  final double completionRate;
  final List<TaskStatusEntry> perTask;
  final List<double> dailyRates; // 7 entries (Mon-Sun) for weekly view
  final int perfectDays; // Feature 4: days where all tasks completed
  final RepeatType? dominantRepeatType; // Feature 6: most common repeat type

  const TaskStatsData({
    required this.completed,
    required this.total,
    required this.missed,
    required this.bestStreak,
    required this.completionRate,
    required this.perTask,
    required this.dailyRates,
    this.perfectDays = 0,
    this.dominantRepeatType,
  });

  static const empty = TaskStatsData(
    completed: 0,
    total: 0,
    missed: 0,
    bestStreak: 0,
    completionRate: 0,
    perTask: [],
    dailyRates: [0, 0, 0, 0, 0, 0, 0],
  );
}

String _formatTimeSlot(TimeOfDay? start, TimeOfDay? end) {
  if (start == null || end == null) return '';
  String fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  return '${fmt(start)} – ${fmt(end)}';
}

final taskStatsProvider = FutureProvider<TaskStatsData>((ref) async {
  final tasksAsync = ref.watch(tasksStreamProvider);
  final days = ref.watch(usageStatsDaysProvider);

  final tasks = tasksAsync.valueOrNull;
  if (tasks == null) return TaskStatsData.empty;

  final now = DateTime.now();
  final repo = getIt<TaskRepository>();
  final activeTasks = tasks.where((t) => !t.archived).toList();

  int total = 0;
  int completed = 0;
  int missed = 0;

  final Map<String, _TaskAgg> taskAgg = {};
  final List<int> dayTotal = List.filled(7, 0);
  final List<int> dayCompleted = List.filled(7, 0);

  // Track perfect days: per-date totals
  final Map<String, int> dateTotalMap = {};
  final Map<String, int> dateCompletedMap = {};

  for (int d = 0; d < days; d++) {
    final date = DateTime(now.year, now.month, now.day - d);
    final weekdayIdx = (date.weekday - 1);
    final dateKey = '${date.year}-${date.month}-${date.day}';

    for (final task in activeTasks) {
      if (!occursOnTask(task, date)) continue;
      total++;
      dayTotal[weekdayIdx]++;
      dateTotalMap[dateKey] = (dateTotalMap[dateKey] ?? 0) + 1;

      TaskCompletionStatus status = TaskCompletionStatus.upcoming;
      try {
        status = await computeTaskStatus(task, date, repo);
      } catch (_) {}

      if (status == TaskCompletionStatus.completed) {
        completed++;
        dayCompleted[weekdayIdx]++;
        dateCompletedMap[dateKey] = (dateCompletedMap[dateKey] ?? 0) + 1;
      } else if (status == TaskCompletionStatus.missed) {
        missed++;
      }

      final agg = taskAgg.putIfAbsent(
        task.id,
        () => _TaskAgg(task: task, status: status),
      );
      if (status == TaskCompletionStatus.completed) agg.completedCount++;
      agg.totalCount++;
      if (status == TaskCompletionStatus.missed) {
        agg.status = TaskCompletionStatus.missed;
      } else if (status == TaskCompletionStatus.upcoming &&
          agg.status == TaskCompletionStatus.completed) {
        agg.status = TaskCompletionStatus.upcoming;
      }
    }
  }

  // Perfect days count (Feature 4)
  int perfectDays = 0;
  for (final dateKey in dateTotalMap.keys) {
    final dt = dateTotalMap[dateKey] ?? 0;
    final dc = dateCompletedMap[dateKey] ?? 0;
    if (dt > 0 && dc == dt) perfectDays++;
  }

  // Dominant repeat type (Feature 6)
  final repeatCounts = <RepeatType, int>{};
  for (final task in activeTasks) {
    final rt = task.repeatType;
    if (rt != null) {
      repeatCounts[rt] = (repeatCounts[rt] ?? 0) + 1;
    }
  }
  RepeatType? dominantRepeatType;
  if (repeatCounts.isNotEmpty) {
    dominantRepeatType = repeatCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  // Build per-task entries sorted: missed first, then upcoming, then completed
  final perTask = taskAgg.values.toList()
    ..sort((a, b) {
      const order = {
        TaskCompletionStatus.missed: 0,
        TaskCompletionStatus.upcoming: 1,
        TaskCompletionStatus.completed: 2,
        TaskCompletionStatus.hidden: 3,
      };
      return (order[a.status] ?? 3).compareTo(order[b.status] ?? 3);
    });

  final entries = perTask.map((agg) {
    return TaskStatusEntry(
      title: agg.task.title,
      status: agg.status,
      streak: agg.task.streak,
      timeSlot: _formatTimeSlot(agg.task.startTime, agg.task.endTime),
      startTime: agg.task.startTime,
      endTime: agg.task.endTime,
    );
  }).toList();

  final bestStreak = activeTasks.isEmpty
      ? 0
      : activeTasks.map((t) => t.streak).reduce((a, b) => a > b ? a : b);

  final dailyRates = List.generate(7, (i) {
    if (dayTotal[i] == 0) return 0.0;
    return dayCompleted[i] / dayTotal[i];
  });

  return TaskStatsData(
    completed: completed,
    total: total,
    missed: missed,
    bestStreak: bestStreak,
    completionRate: total > 0 ? completed / total : 0,
    perTask: entries,
    dailyRates: dailyRates,
    perfectDays: perfectDays,
    dominantRepeatType: dominantRepeatType,
  );
});

class _TaskAgg {
  final Task task;
  TaskCompletionStatus status;
  int completedCount = 0;
  int totalCount = 0;

  _TaskAgg({required this.task, required this.status});
}

// ── Enriched Usage Stats (Features 1, 2, 3, 5) ──

final enrichedUsageStatsProvider =
    FutureProvider<EnrichedUsageStats?>((ref) async {
  final rawData = await ref.watch(usageStatsProvider.future);
  if (rawData == null) return null;

  final taskStatsAsync = ref.watch(tasksStreamProvider);
  final activeTasks = (taskStatsAsync.valueOrNull ?? [])
      .where((t) => !t.archived)
      .toList();

  final totalMinutes =
      (rawData['totalScreenTimeMinutes'] as num?)?.toInt() ?? 0;
  final focusMinutes =
      (rawData['focusTimeMinutes'] as num?)?.toInt() ?? 0;
  final prevented =
      (rawData['preventedDistractions'] as num?)?.toInt() ?? 0;
  final idleMinutes = totalMinutes - focusMinutes;

  // Parse hourly usage
  final hourlyRaw = rawData['hourlyUsage'] as List<dynamic>? ?? [];
  final hourly = hourlyRaw.map((e) => (e as num).toInt()).toList();
  while (hourly.length < 24) {
    hourly.add(0);
  }

  // Build hour annotations (Feature 2)
  // Determine which hours have a task scheduled
  final taskHours = <int>{};
  for (final task in activeTasks) {
    if (task.startTime != null && task.endTime != null) {
      final startHour = task.startTime!.hour;
      final endHour = task.endTime!.hour;
      // Include all hours the task spans
      for (int h = startHour; h <= endHour && h < 24; h++) {
        taskHours.add(h);
      }
    }
  }

  final hourAnnotations = List.generate(24, (h) {
    final hasTask = taskHours.contains(h);
    final minutes = hourly[h];
    // Thresholds: >30min = high, <10min = low, else normal
    final level = minutes > 30
        ? ScreenTimeLevel.high
        : minutes < 10
            ? ScreenTimeLevel.low
            : ScreenTimeLevel.normal;
    return HourAnnotation(hour: h, hasTask: hasTask, screenTimeLevel: level);
  });

  // Parse and categorize top apps (Feature 3)
  final rawApps = (rawData['topApps'] as List<dynamic>? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  final topApps = rawApps.map((app) {
    final pkg = app['packageName'] as String? ?? '';
    return AppUsageEntry(
      packageName: pkg,
      appName: app['appName'] as String? ?? pkg,
      usageMinutes: (app['usageMinutes'] as num?)?.toInt() ?? 0,
      iconBase64: app['iconBase64'] as String? ?? '',
      category: categorizeApp(pkg),
    );
  }).toList();

  // Aggregate category minutes (Feature 3)
  int productiveMin = 0;
  int distractingMin = 0;
  int neutralMin = 0;
  for (final app in topApps) {
    switch (app.category) {
      case AppCategory.productive:
        productiveMin += app.usageMinutes;
      case AppCategory.distracting:
        distractingMin += app.usageMinutes;
      case AppCategory.neutral:
        neutralMin += app.usageMinutes;
    }
  }

  return EnrichedUsageStats(
    totalScreenTimeMinutes: totalMinutes,
    focusTimeMinutes: focusMinutes,
    idleTimeMinutes: idleMinutes,
    preventedDistractions: prevented,
    hourlyUsage: hourly,
    hourAnnotations: hourAnnotations,
    topApps: topApps,
    productiveMinutes: productiveMin,
    distractingMinutes: distractingMin,
    neutralMinutes: neutralMin,
    // TODO(kotlin): Compute trend when previous-period data is available
    trendPercentage: null,
  );
});

// ── Heatmap Data (Feature 4) — always 30 days ──

final heatmapDataProvider =
    FutureProvider<List<DailyCompletion>>((ref) async {
  final tasksAsync = ref.watch(tasksStreamProvider);
  final tasks = tasksAsync.valueOrNull;
  if (tasks == null) return [];

  final now = DateTime.now();
  final repo = getIt<TaskRepository>();
  final activeTasks = tasks.where((t) => !t.archived).toList();

  final results = <DailyCompletion>[];

  for (int d = 29; d >= 0; d--) {
    final date = DateTime(now.year, now.month, now.day - d);
    int dayTotal = 0;
    int dayCompleted = 0;

    for (final task in activeTasks) {
      if (!occursOnTask(task, date)) continue;
      dayTotal++;
      try {
        final status = await computeTaskStatus(task, date, repo);
        if (status == TaskCompletionStatus.completed) dayCompleted++;
      } catch (_) {}
    }

    results.add(DailyCompletion(
      date: date,
      completionRate: dayTotal > 0 ? dayCompleted / dayTotal : 0,
      totalTasks: dayTotal,
    ));
  }

  return results;
});

/// Number of perfect days in the last 30 days (Feature 4).
final perfectDaysCountProvider = Provider<int>((ref) {
  final heatmap = ref.watch(heatmapDataProvider).valueOrNull ?? [];
  return heatmap
      .where((d) => d.totalTasks > 0 && d.completionRate == 1.0)
      .length;
});
