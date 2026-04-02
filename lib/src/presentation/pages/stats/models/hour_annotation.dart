/// Screen time intensity level for a given hour.
enum ScreenTimeLevel { low, normal, high }

/// The processing mode for a given hour in the stacked bar chart.
/// - [offline]: Task with isOfflineFocus=true → all screen time is distraction.
/// - [digital]: Normal hour (with or without task) → split by app category.
enum HourMode { offline, digital }

/// Annotation for a single hour in the hourly activity chart.
/// Contains both the legacy single-color data and per-category minute
/// breakdown for stacked bar rendering.
class HourAnnotation {
  final int hour;
  final bool hasTask;
  final ScreenTimeLevel screenTimeLevel;

  /// Processing mode for this hour (determines bar rendering).
  final HourMode mode;

  /// Per-category minutes (used for stacked bars in digital/offline mode).
  final int productiveMinutes;
  final int distractingMinutes;
  final int neutralMinutes;

  const HourAnnotation({
    required this.hour,
    required this.hasTask,
    required this.screenTimeLevel,
    this.mode = HourMode.digital,
    this.productiveMinutes = 0,
    this.distractingMinutes = 0,
    this.neutralMinutes = 0,
  });
}
