/// Domain entity representing a weekly AI-generated productivity report.
///
/// The schema mirrors the UI consumed by `AiReportSheet`:
///   * [score]    — 1..10 wellbeing score
///   * [summary]  — one short sentence overall assessment
///   * [insights] — exactly 3 short insights (screen-time, distractions,
///                  task habits)
///   * [tips]     — exactly 2 actionable tips (screen time, task habits)
class AiReport {
  final int score;
  final String summary;
  final List<String> insights;
  final List<String> tips;

  const AiReport({
    required this.score,
    required this.summary,
    required this.insights,
    required this.tips,
  });
}
