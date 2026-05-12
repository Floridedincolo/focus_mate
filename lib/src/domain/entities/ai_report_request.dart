/// Aggregated weekly statistics used as input for the AI weekly report.
///
/// The Cloud Function builds the prompt from these fields server-side;
/// the client never sends a free-form prompt string. All time-based
/// values are in minutes.
class AiReportRequest {
  // ── Screen time ─────────────────────────────────────────────────────
  final int totalScreenMinutes;
  final int focusMinutes; // time during active blocking
  final int idleMinutes;
  final int productiveMinutes;
  final int neutralMinutes;
  final int distractingMinutes;
  final int preventedDistractions;

  // ── Top apps (sorted desc by minutes) ──────────────────────────────
  final List<AiReportTopApp> topApps;

  // ── Hourly usage (24 entries, index = hour 0..23, value = minutes) ─
  final List<int> hourlyUsage;

  // ── Daily usage / breakdown (7 entries, Mon..Sun) ──────────────────
  final List<AiReportDayBreakdown> dailyBreakdown;

  // ── Hours flagged with task-vs-screen-time annotation ──────────────
  final List<int> highScreenTaskHours; // hours with task + high screen time
  final List<int> lowScreenTaskHours; // hours with task + low screen time
  final int peakUsageHour;

  // ── Trend vs previous week ─────────────────────────────────────────
  /// Percentage change in screen time (negative = improvement).
  /// `null` if there is no previous-week baseline.
  final double? trendPercentage;

  // ── Tasks ──────────────────────────────────────────────────────────
  final int completedTasks;
  final int totalTasks;
  final int missedTasks;
  final int bestStreak;
  final double completionRate; // 0..1
  final int perfectDays;
  final String? dominantRepeatType;
  final List<AiReportTaskEntry> perTask;

  const AiReportRequest({
    required this.totalScreenMinutes,
    required this.focusMinutes,
    required this.idleMinutes,
    required this.productiveMinutes,
    required this.neutralMinutes,
    required this.distractingMinutes,
    required this.preventedDistractions,
    required this.topApps,
    required this.hourlyUsage,
    required this.dailyBreakdown,
    required this.highScreenTaskHours,
    required this.lowScreenTaskHours,
    required this.peakUsageHour,
    required this.trendPercentage,
    required this.completedTasks,
    required this.totalTasks,
    required this.missedTasks,
    required this.bestStreak,
    required this.completionRate,
    required this.perfectDays,
    required this.dominantRepeatType,
    required this.perTask,
  });
}

enum AiReportAppCategory { productive, neutral, distracting }

class AiReportTopApp {
  final String appName;
  final String packageName;
  final AiReportAppCategory category;
  final int minutes;

  const AiReportTopApp({
    required this.appName,
    required this.packageName,
    required this.category,
    required this.minutes,
  });
}

class AiReportDayBreakdown {
  final int totalMinutes;
  final int productiveMinutes;
  final int neutralMinutes;
  final int distractingMinutes;

  const AiReportDayBreakdown({
    required this.totalMinutes,
    required this.productiveMinutes,
    required this.neutralMinutes,
    required this.distractingMinutes,
  });
}

class AiReportTaskEntry {
  final String title;
  final String status; // completed | upcoming | missed | hidden
  final int streak;
  final String timeSlot; // may be empty

  const AiReportTaskEntry({
    required this.title,
    required this.status,
    required this.streak,
    required this.timeSlot,
  });
}
