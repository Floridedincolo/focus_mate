import 'app_category.dart';
import 'hour_annotation.dart';

/// Per-day category breakdown for daily bar charts.
class DayCategoryBreakdown {
  final int totalMinutes;
  final int productiveMinutes;
  final int distractingMinutes;
  final int neutralMinutes;

  const DayCategoryBreakdown({
    this.totalMinutes = 0,
    this.productiveMinutes = 0,
    this.distractingMinutes = 0,
    this.neutralMinutes = 0,
  });
}

/// Typed entry for a single app's usage data.
class AppUsageEntry {
  final String packageName;
  final String appName;
  final int usageMinutes;
  final String iconBase64;
  final AppCategory category;

  const AppUsageEntry({
    required this.packageName,
    required this.appName,
    required this.usageMinutes,
    required this.iconBase64,
    required this.category,
  });
}

/// Typed wrapper for the enriched usage statistics, replacing the raw
/// map from the MethodChannel.
///
/// Combines platform data with computed fields for Features 1, 2, 3, 5.
class EnrichedUsageStats {
  /// Total screen time across the selected period.
  final int totalScreenTimeMinutes;

  /// Time spent while a block template was active (Feature 1).
  /// TODO(kotlin): Currently always 0. Wire to AppBlockService tracking.
  final int focusTimeMinutes;

  /// Screen time outside of block-template windows (Feature 1).
  final int idleTimeMinutes;

  /// Number of times a blocked app launch was prevented (Feature 1).
  /// TODO(kotlin): Currently always 0. Wire to AppBlockService counter.
  final int preventedDistractions;

  /// Hourly usage in minutes (24 elements, index 0 = midnight).
  final List<int> hourlyUsage;

  /// Per-app per-hour usage in minutes: packageName -> [24 ints].
  /// Used for computing stacked bar category breakdowns.
  final Map<String, List<int>> hourlyAppUsage;

  /// Per-hour annotations with task correlation (Feature 2).
  final List<HourAnnotation> hourAnnotations;

  /// Per-hour focus time in minutes (24 entries).
  /// Computed from tasks with blocking templates that cover each hour.
  final List<int> hourlyFocusMinutes;

  /// Per-hour blocked distractions (24 entries).
  /// Daily total distributed proportionally across blocking-task hours.
  final List<int> hourlyBlockedDistractions;

  /// Top apps with category enrichment (Feature 3).
  final List<AppUsageEntry> topApps;

  /// Aggregate minutes by category (Feature 3).
  final int productiveMinutes;
  final int distractingMinutes;
  final int neutralMinutes;

  /// Per-day usage in minutes (length = days in period). Index 0 = first day.
  final List<int> dailyUsage;

  /// Per-app per-day usage in minutes: packageName -> [days ints].
  final Map<String, List<int>> dailyAppUsage;

  /// Weekday index of the first day in the period (0=Mon..6=Sun).
  final int startWeekday;

  /// Per-day category breakdown for weekly/monthly chart bars.
  final List<DayCategoryBreakdown> dailyCategoryBreakdown;

  /// Period-over-period trend for screen time (Feature 5).
  /// Null until previous-period data is available from the backend.
  /// TODO(kotlin): Query previous period and compute trend percentage.
  final double? trendPercentage;

  const EnrichedUsageStats({
    required this.totalScreenTimeMinutes,
    required this.focusTimeMinutes,
    required this.idleTimeMinutes,
    required this.preventedDistractions,
    required this.hourlyUsage,
    this.hourlyAppUsage = const {},
    required this.hourAnnotations,
    this.hourlyFocusMinutes = const [],
    this.hourlyBlockedDistractions = const [],
    this.dailyUsage = const [],
    this.dailyAppUsage = const {},
    this.startWeekday = 0,
    this.dailyCategoryBreakdown = const [],
    required this.topApps,
    required this.productiveMinutes,
    required this.distractingMinutes,
    required this.neutralMinutes,
    this.trendPercentage,
  });

  static const empty = EnrichedUsageStats(
    totalScreenTimeMinutes: 0,
    focusTimeMinutes: 0,
    idleTimeMinutes: 0,
    preventedDistractions: 0,
    hourlyUsage: [],
    hourAnnotations: [],
    topApps: [],
    productiveMinutes: 0,
    distractingMinutes: 0,
    neutralMinutes: 0,
  );
}
