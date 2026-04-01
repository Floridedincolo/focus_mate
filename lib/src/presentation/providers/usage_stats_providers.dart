import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/service_locator.dart';
import '../../data/datasources/usage_stats_datasource.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_completion_status.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/usecases/compute_task_status.dart';
import '../../domain/usecases/task_occurrence.dart';
import 'task_providers.dart';

final usageStatsDsProvider = Provider<UsageStatsDataSource>(
  (ref) => getIt<UsageStatsDataSource>(),
);

final hasUsagePermissionProvider = FutureProvider<bool>((ref) async {
  final ds = ref.watch(usageStatsDsProvider);
  return ds.hasUsagePermission();
});

/// Selected number of days: 1 = Today, 7 = This Week
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

  const TaskStatusEntry({
    required this.title,
    required this.status,
    required this.streak,
    required this.timeSlot,
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

  const TaskStatsData({
    required this.completed,
    required this.total,
    required this.missed,
    required this.bestStreak,
    required this.completionRate,
    required this.perTask,
    required this.dailyRates,
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

  // For per-task entries (today view: per task; weekly view: aggregate)
  final Map<String, _TaskAgg> taskAgg = {};

  // For weekly pattern (7 days, Mon=0..Sun=6)
  final List<int> dayTotal = List.filled(7, 0);
  final List<int> dayCompleted = List.filled(7, 0);

  for (int d = 0; d < days; d++) {
    final date = DateTime(now.year, now.month, now.day - d);
    final weekdayIdx = (date.weekday - 1); // Mon=0..Sun=6

    for (final task in activeTasks) {
      if (!occursOnTask(task, date)) continue;
      total++;
      dayTotal[weekdayIdx]++;

      TaskCompletionStatus status = TaskCompletionStatus.upcoming;
      try {
        status = await computeTaskStatus(task, date, repo);
      } catch (_) {}

      if (status == TaskCompletionStatus.completed) {
        completed++;
        dayCompleted[weekdayIdx]++;
      } else if (status == TaskCompletionStatus.missed) {
        missed++;
      }

      // Aggregate per task
      final agg = taskAgg.putIfAbsent(
        task.id,
        () => _TaskAgg(task: task, status: status),
      );
      if (status == TaskCompletionStatus.completed) agg.completedCount++;
      agg.totalCount++;
      // Keep the "worst" status for display (missed > upcoming > completed)
      if (status == TaskCompletionStatus.missed) {
        agg.status = TaskCompletionStatus.missed;
      } else if (status == TaskCompletionStatus.upcoming &&
          agg.status == TaskCompletionStatus.completed) {
        agg.status = TaskCompletionStatus.upcoming;
      }
    }
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
    );
  }).toList();

  // Best streak across all tasks
  final bestStreak = activeTasks.isEmpty
      ? 0
      : activeTasks.map((t) => t.streak).reduce((a, b) => a > b ? a : b);

  // Daily rates (Mon-Sun)
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
  );
});

class _TaskAgg {
  final Task task;
  TaskCompletionStatus status;
  int completedCount = 0;
  int totalCount = 0;

  _TaskAgg({required this.task, required this.status});
}
