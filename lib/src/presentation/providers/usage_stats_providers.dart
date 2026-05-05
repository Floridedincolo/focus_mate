import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- Import nou pentru citirea blocărilor pe ore

import '../../core/service_locator.dart';
import '../../data/datasources/local_app_classification_datasource.dart';
import '../../data/datasources/usage_stats_datasource.dart';
import '../../domain/entities/app_classification.dart';
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

// ── Per-app user classifications (override category + exclude) ──

final appClassificationDsProvider =
    Provider<LocalAppClassificationDataSource>(
        (ref) => LocalAppClassificationDataSource());

class AppClassificationsNotifier
    extends StateNotifier<Map<String, AppClassification>> {
  final LocalAppClassificationDataSource _ds;

  AppClassificationsNotifier(this._ds) : super({}) {
    _load();
  }

  Future<void> _load() async {
    state = await _ds.loadAll();
  }

  Future<void> setCategory(String pkg, AppCategory category) async {
    final next = Map<String, AppClassification>.from(state);
    final existing = next[pkg] ?? AppClassification(packageName: pkg);
    next[pkg] = existing.copyWith(userCategory: category);
    state = next;
    await _ds.saveAll(next);
  }

  Future<void> clearCategory(String pkg) async {
    final next = Map<String, AppClassification>.from(state);
    final existing = next[pkg];
    if (existing == null) return;
    next[pkg] = existing.copyWith(clearUserCategory: true);
    state = next;
    await _ds.saveAll(next);
  }

  Future<void> setExcluded(String pkg, bool excluded) async {
    final next = Map<String, AppClassification>.from(state);
    final existing = next[pkg] ?? AppClassification(packageName: pkg);
    next[pkg] = existing.copyWith(excluded: excluded);
    state = next;
    await _ds.saveAll(next);
  }
}

final appClassificationsProvider = StateNotifierProvider<
    AppClassificationsNotifier, Map<String, AppClassification>>((ref) {
  return AppClassificationsNotifier(ref.watch(appClassificationDsProvider));
});

/// Resolves the effective category for an app, applying user overrides.
AppCategory resolveCategory(
  String packageName,
  String? appName,
  Map<String, AppClassification> classifications,
) {
  final override = classifications[packageName]?.userCategory;
  if (override != null) return override;
  return categorizeApp(packageName, appName: appName);
}

final usageStatsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final hasPermission = await ref.watch(hasUsagePermissionProvider.future);
  if (!hasPermission) return null;
  final ds = ref.watch(usageStatsDsProvider);
  final days = ref.watch(usageStatsDaysProvider);
  final dayOffset = ref.watch(dateOffsetProvider);
  return ds.getUsageStats(days: days, dayOffset: dayOffset);
});

/// Standalone per-period raw stats fetch (used by per-app detail screen).
/// Independent of the global [usageStatsDaysProvider] so the detail screen
/// can pick its own period without affecting the main stats page.
final usageStatsForPeriodProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, int>((ref, days) async {
  final hasPermission = await ref.watch(hasUsagePermissionProvider.future);
  if (!hasPermission) return null;
  final ds = ref.watch(usageStatsDsProvider);
  return ds.getUsageStats(days: days, dayOffset: 0);
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

  final classifications = ref.watch(appClassificationsProvider);
  bool isExcluded(String pkg) => classifications[pkg]?.excluded ?? false;

  // Inițializăm accesul la baza de date locală pentru a citi block-urile pe ore
  final prefs = await SharedPreferences.getInstance();
  final dayOffset = ref.watch(dateOffsetProvider);
  final targetDate = DateTime.now().add(Duration(days: dayOffset));
  // Formatăm data exact cum o face Kotlin (yyyy-MM-dd)
  final dateStr = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

  final taskStatsAsync = ref.watch(tasksStreamProvider);
  final activeTasks = (taskStatsAsync.valueOrNull ?? [])
      .where((t) => !t.archived)
      .toList();

  final rawTotalMinutes =
      (rawData['totalScreenTimeMinutes'] as num?)?.toInt() ?? 0;
  // focusMinutes computed later from task-based hourlyFocus
  var focusMinutes = 0;
  final prevented =
      (rawData['preventedDistractions'] as num?)?.toInt() ?? 0;
  var idleMinutes = 0;

  // Parse hourly usage
  final hourlyRaw = rawData['hourlyUsage'] as List<dynamic>? ?? [];
  final hourly = hourlyRaw.map((e) => (e as num).toInt()).toList();
  while (hourly.length < 24) {
    hourly.add(0);
  }

  // Parse per-app per-hour usage from Kotlin (skip excluded apps)
  final rawHourlyApp = rawData['hourlyAppUsage'] as Map<dynamic, dynamic>? ?? {};
  final hourlyAppUsage = <String, List<int>>{};
  // Track minutes per hour we need to subtract from totals due to exclusions.
  final excludedHourlyAdjust = List<int>.filled(24, 0);
  for (final entry in rawHourlyApp.entries) {
    final pkg = entry.key as String;
    final hours = (entry.value as List<dynamic>).map((e) => (e as num).toInt()).toList();
    while (hours.length < 24) {
      hours.add(0);
    }
    if (isExcluded(pkg)) {
      for (int h = 0; h < 24; h++) {
        excludedHourlyAdjust[h] += hours[h];
      }
      continue;
    }
    hourlyAppUsage[pkg] = hours;
  }

  // Subtract excluded apps' minutes from the global hourly array.
  for (int h = 0; h < 24; h++) {
    hourly[h] = (hourly[h] - excludedHourlyAdjust[h]).clamp(0, 1 << 30);
  }

  // Parse top apps early so annotations can use app names for categorization (skip excluded)
  final rawAppsAll = (rawData['topApps'] as List<dynamic>? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  int excludedTotalMinutes = 0;
  for (final a in rawAppsAll) {
    final pkg = a['packageName'] as String? ?? '';
    if (isExcluded(pkg)) {
      excludedTotalMinutes += (a['usageMinutes'] as num?)?.toInt() ?? 0;
    }
  }
  final rawApps = rawAppsAll
      .where((a) => !isExcluded(a['packageName'] as String? ?? ''))
      .toList();

  // Build hour annotations
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

    final isOffline = hasTask && tasks.any((t) => t.isOfflineFocus);

    if (isOffline) {
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

      final cat = resolveCategory(pkg, appName, classifications);
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

  // Categorize top apps (excluded already filtered out of rawApps above)
  final topApps = rawApps.map((app) {
    final pkg = app['packageName'] as String? ?? '';
    return AppUsageEntry(
      packageName: pkg,
      appName: app['appName'] as String? ?? pkg,
      usageMinutes: (app['usageMinutes'] as num?)?.toInt() ?? 0,
      iconBase64: app['iconBase64'] as String? ?? '',
      category: resolveCategory(pkg, app['appName'] as String?, classifications),
    );
  }).toList();

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

  // Add offline task hours to distracting minutes (consistency with Hourly Chart)
  for (final ann in hourAnnotations) {
    if (ann.mode == HourMode.offline) {
      distractingMin += ann.distractingMinutes;
    }
  }

  // Compute per-hour focus time from tasks with blocking templates
  // For today (dayOffset == 0), clamp to current time so we don't count future hours
  final now = DateTime.now();
  final isToday = dayOffset == 0;
  final nowH = now.hour;
  final nowM = now.minute;

  final hourlyFocus = List<int>.filled(24, 0);
  for (final task in activeTasks) {
    if (task.blockTemplateId == null) continue;
    if (task.startTime == null || task.endTime == null) continue;
    if (!occursOnTask(task, targetDate)) continue;
    final sH = task.startTime!.hour;
    final sM = task.startTime!.minute;
    var eH = task.endTime!.hour;
    var eM = task.endTime!.minute;

    // For today, clamp end time to now so future focus time isn't counted
    if (isToday) {
      if (eH > nowH || (eH == nowH && eM > nowM)) {
        eH = nowH;
        eM = nowM;
      }
    }

    // Skip if the task hasn't started yet today
    if (isToday && (sH > nowH || (sH == nowH && sM > nowM))) continue;

    for (int h = sH; h <= eH && h < 24; h++) {
      final overlapStart = (h == sH) ? sM : 0;
      final overlapEnd = (h == eH) ? eM : 60;
      final minutes = (overlapEnd - overlapStart).clamp(0, 60);
      hourlyFocus[h] += minutes;
    }
  }
  for (int h = 0; h < 24; h++) {
    if (hourlyFocus[h] > 60) hourlyFocus[h] = 60;
  }

  final totalMinutes =
      (rawTotalMinutes - excludedTotalMinutes).clamp(0, 1 << 30);

  // Compute total focus from hourly task-based data
  focusMinutes = hourlyFocus.fold(0, (sum, m) => sum + m);
  idleMinutes = totalMinutes - focusMinutes;

  // Citim din telefon numărul EXACT de distrageri prevenite pentru fiecare oră în parte
  final hourlyBlocked = List<int>.filled(24, 0);
  for (int h = 0; h < 24; h++) {
    final hourStr = h.toString().padLeft(2, '0');
    // Generăm cheia (ex: prevented_distractions_2026-04-07_14)
    final key = 'prevented_distractions_${dateStr}_$hourStr';
    hourlyBlocked[h] = prefs.getInt(key) ?? 0;
  }

  // Parse per-day data for weekly/monthly charts
  final rawDaily = rawData['dailyUsage'] as List<dynamic>? ?? [];
  final dailyUsage = rawDaily.map((e) => (e as num).toInt()).toList();

  final rawDailyApp = rawData['dailyAppUsage'] as Map<dynamic, dynamic>? ?? {};
  final dailyAppUsage = <String, List<int>>{};
  final excludedDailyAdjust = List<int>.filled(dailyUsage.length, 0);
  for (final entry in rawDailyApp.entries) {
    final pkg = entry.key as String;
    final days = (entry.value as List<dynamic>).map((e) => (e as num).toInt()).toList();
    if (isExcluded(pkg)) {
      for (int d = 0; d < days.length && d < excludedDailyAdjust.length; d++) {
        excludedDailyAdjust[d] += days[d];
      }
      continue;
    }
    dailyAppUsage[pkg] = days;
  }
  // Subtract excluded apps' minutes from per-day totals.
  for (int d = 0; d < dailyUsage.length; d++) {
    dailyUsage[d] = (dailyUsage[d] - excludedDailyAdjust[d]).clamp(0, 1 << 30);
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

      final cat = resolveCategory(pkg, appName, classifications);
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
    hourlyBlockedDistractions: hourlyBlocked, // Acum trimite lista cu valorile reale pe ore!
    dailyUsage: dailyUsage,
    dailyAppUsage: dailyAppUsage,
    startWeekday: startWeekday,
    dailyCategoryBreakdown: dailyCategoryBreakdown,
    topApps: topApps,
    productiveMinutes: productiveMin,
    distractingMinutes: distractingMin,
    neutralMinutes: neutralMin,
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