/// Data point for the 30-day productivity heatmap (Feature 4).
class DailyCompletion {
  final DateTime date;
  final double completionRate;
  final int totalTasks;

  const DailyCompletion({
    required this.date,
    required this.completionRate,
    required this.totalTasks,
  });
}
