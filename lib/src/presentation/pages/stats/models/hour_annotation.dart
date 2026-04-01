/// Screen time intensity level for a given hour.
enum ScreenTimeLevel { low, normal, high }

/// Annotation for a single hour in the hourly activity chart (Feature 2).
/// Indicates whether a task was scheduled during that hour and the
/// user's screen-time intensity.
class HourAnnotation {
  final int hour;
  final bool hasTask;
  final ScreenTimeLevel screenTimeLevel;

  const HourAnnotation({
    required this.hour,
    required this.hasTask,
    required this.screenTimeLevel,
  });
}
