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

/// Day offset for date navigation (0 = today, -1 = yesterday, etc.)
final dateOffsetProvider = StateProvider<int>((ref) => 0);

/// Whether we're in Trend mode (vs Day/Week).
final isTrendModeProvider = StateProvider<bool>((ref) => false);

/// Sub-period inside Trend view: 30 = 1M, 90 = 3M, 365 = Max.
final trendPeriodProvider = StateProvider<int>((ref) => 30);

final usageStatsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final hasPermission = await ref.watch(hasUsagePermissionProvider.future);
  if (!hasPermission) return null;
  final ds = ref.watch(usageStatsDsProvider);
  final days = ref.watch(usageStatsDaysProvider);
  final dayOffset = ref.watch(dateOffsetProvider);
  return ds.getUsageStats(days: days, dayOffset: dayOffset);
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

  // Parse per-app per-hour usage from Kotlin
  final rawHourlyApp = rawData['hourlyAppUsage'] as Map<dynamic, dynamic>? ?? {};
  final hourlyAppUsage = <String, List<int>>{};
  for (final entry in rawHourlyApp.entries) {
    final pkg = entry.key as String;
    final hours = (entry.value as List<dynamic>).map((e) => (e as num).toInt()).toList();
    while (hours.length < 24) {
      hours.add(0);
    }
    hourlyAppUsage[pkg] = hours;
  }

  // Parse top apps early so annotations can use app names for categorization
  final rawApps = (rawData['topApps'] as List<dynamic>? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  // Build hour annotations with 2-mode stacked bar logic:
  // 1. Offline focus task hours: all screen time = distracting (red)
  // 2. All other hours (with or without task): split by app category

  // Map each hour to the task(s) covering it
  final hourTaskInfo = List.generate(24, (_) => <Task>[]);
  for (final task in activeTasks) {
    if (task.startTime != null && task.endTime != null) {
      final startHour = task.startTime!.hour;
      final endHour = task.endTime!.hour;
      for (int h = startHour; h <= endHour && h < 24; h++) {
        hourTaskInfo[h].add(task);
      }
    }
  }

  final hourAnnotations = List.generate(24, (h) {
    final tasks = hourTaskInfo[h];
    final hasTask = tasks.isNotEmpty;
    final minutes = hourly[h];
    final level = minutes > 30
        ? ScreenTimeLevel.high
        : minutes < 10
            ? ScreenTimeLevel.low
            : ScreenTimeLevel.normal;

    // Check if any task in this hour is offline focus
    final isOffline = hasTask && tasks.any((t) => t.isOfflineFocus);

    if (isOffline) {
      // Offline focus: ALL screen time is distraction
      return HourAnnotation(
        hour: h,
        hasTask: true,
        screenTimeLevel: level,
        mode: HourMode.offline,
        productiveMinutes: 0,
        distractingMinutes: minutes,
        neutralMinutes: 0,
      );
    }

    // All other hours: split by app category using per-app per-hour data
    int prodMin = 0;
    int distMin = 0;
    int neutMin = 0;

    for (final entry in hourlyAppUsage.entries) {
      final pkg = entry.key;
      final appMinThisHour = entry.value[h];
      if (appMinThisHour <= 0) continue;

      final appNameMatch = rawApps.where(
        (a) => a['packageName'] == pkg,
      );
      final appName = appNameMatch.isNotEmpty
          ? appNameMatch.first['appName'] as String?
          : null;

      final cat = categorizeApp(pkg, appName: appName);
      switch (cat) {
        case AppCategory.productive:
          prodMin += appMinThisHour;
        case AppCategory.distracting:
          distMin += appMinThisHour;
        case AppCategory.neutral:
          neutMin += appMinThisHour;
      }
    }

    return HourAnnotation(
      hour: h,
      hasTask: hasTask,
      screenTimeLevel: level,
      mode: HourMode.digital,
      productiveMinutes: prodMin,
      distractingMinutes: distMin,
      neutralMinutes: neutMin,
    );
  });

  // Categorize top apps (Feature 3)
  final topApps = rawApps.map((app) {
    final pkg = app['packageName'] as String? ?? '';
    return AppUsageEntry(
      packageName: pkg,
      appName: app['appName'] as String? ?? pkg,
      usageMinutes: (app['usageMinutes'] as num?)?.toInt() ?? 0,
      iconBase64: app['iconBase64'] as String? ?? '',
      category: categorizeApp(pkg, appName: app['appName'] as String?),
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

  // Compute per-hour focus time from tasks with blocking templates
  final hourlyFocus = List<int>.filled(24, 0);
  for (final task in activeTasks) {
    if (task.blockTemplateId == null) continue;
    if (task.startTime == null || task.endTime == null) continue;
    final sH = task.startTime!.hour;
    final sM = task.startTime!.minute;
    final eH = task.endTime!.hour;
    final eM = task.endTime!.minute;
    for (int h = sH; h <= eH && h < 24; h++) {
      // How many minutes of this hour overlap with the task
      final overlapStart = (h == sH) ? sM : 0;
      final overlapEnd = (h == eH) ? eM : 60;
      final minutes = (overlapEnd - overlapStart).clamp(0, 60);
      hourlyFocus[h] += minutes;
    }
  }
  // Cap each hour at 60
  for (int h = 0; h < 24; h++) {
    if (hourlyFocus[h] > 60) hourlyFocus[h] = 60;
  }

  // Distribute blocked distractions across hours with blocking tasks
  final hourlyBlocked = List<int>.filled(24, 0);
  final totalFocusHourMinutes = hourlyFocus.fold(0, (a, b) => a + b);
  if (totalFocusHourMinutes > 0 && prevented > 0) {
    for (int h = 0; h < 24; h++) {
      if (hourlyFocus[h] > 0) {
        hourlyBlocked[h] =
            (prevented * hourlyFocus[h] / totalFocusHourMinutes).round();
      }
    }
  }

  // Parse per-day data for weekly/monthly charts
  final rawDaily = rawData['dailyUsage'] as List<dynamic>? ?? [];
  final dailyUsage = rawDaily.map((e) => (e as num).toInt()).toList();

  final rawDailyApp = rawData['dailyAppUsage'] as Map<dynamic, dynamic>? ?? {};
  final dailyAppUsage = <String, List<int>>{};
  for (final entry in rawDailyApp.entries) {
    final pkg = entry.key as String;
    final days = (entry.value as List<dynamic>).map((e) => (e as num).toInt()).toList();
    dailyAppUsage[pkg] = days;
  }

  final startWeekday = (rawData['startWeekday'] as num?)?.toInt() ?? 0;

  // Compute per-day category breakdown for stacked daily bars
  final dailyCategoryBreakdown = List.generate(dailyUsage.length, (d) {
    int dayProd = 0, dayDist = 0, dayNeut = 0;
    for (final entry in dailyAppUsage.entries) {
      final pkg = entry.key;
      if (d >= entry.value.length) continue;
      final appMinThisDay = entry.value[d];
      if (appMinThisDay <= 0) continue;

      final appNameMatch = rawApps.where((a) => a['packageName'] == pkg);
      final appName = appNameMatch.isNotEmpty
          ? appNameMatch.first['appName'] as String?
          : null;

      final cat = categorizeApp(pkg, appName: appName);
      switch (cat) {
        case AppCategory.productive:
          dayProd += appMinThisDay;
        case AppCategory.distracting:
          dayDist += appMinThisDay;
        case AppCategory.neutral:
          dayNeut += appMinThisDay;
      }
    }
    return DayCategoryBreakdown(
      totalMinutes: dailyUsage[d],
      productiveMinutes: dayProd,
      distractingMinutes: dayDist,
      neutralMinutes: dayNeut,
    );
  });

  return EnrichedUsageStats(
    totalScreenTimeMinutes: totalMinutes,
    focusTimeMinutes: focusMinutes,
    idleTimeMinutes: idleMinutes,
    preventedDistractions: prevented,
    hourlyUsage: hourly,
    hourlyAppUsage: hourlyAppUsage,
    hourAnnotations: hourAnnotations,
    hourlyFocusMinutes: hourlyFocus,
    hourlyBlockedDistractions: hourlyBlocked,
    dailyUsage: dailyUsage,
    dailyAppUsage: dailyAppUsage,
    startWeekday: startWeekday,
    dailyCategoryBreakdown: dailyCategoryBreakdown,
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
