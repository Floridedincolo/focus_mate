import '../../domain/entities/ai_report.dart';
import '../../domain/entities/ai_report_request.dart';

/// Wire format returned by the `generateAiReport` Cloud Function.
class AiReportDto {
  final int score;
  final String summary;
  final List<String> insights;
  final List<String> tips;

  const AiReportDto({
    required this.score,
    required this.summary,
    required this.insights,
    required this.tips,
  });

  factory AiReportDto.fromJson(Map<String, dynamic> json) {
    final score = (json['score'] as num?)?.toInt();
    final summary = json['summary'];
    final insightsRaw = json['insights'];
    final tipsRaw = json['tips'];

    if (score == null ||
        summary is! String ||
        insightsRaw is! List ||
        tipsRaw is! List) {
      throw const FormatException(
        'AI report payload is missing one or more required fields '
        '(score, summary, insights, tips).',
      );
    }

    return AiReportDto(
      score: score.clamp(1, 10),
      summary: summary,
      insights: insightsRaw.map((e) => e.toString()).toList(),
      tips: tipsRaw.map((e) => e.toString()).toList(),
    );
  }

  AiReport toEntity() => AiReport(
        score: score,
        summary: summary,
        insights: insights,
        tips: tips,
      );
}

/// Serialised payload sent to the `generateAiReport` Cloud Function.
extension AiReportRequestDto on AiReportRequest {
  Map<String, dynamic> toJson() => {
        'totalScreenMinutes': totalScreenMinutes,
        'focusMinutes': focusMinutes,
        'idleMinutes': idleMinutes,
        'productiveMinutes': productiveMinutes,
        'neutralMinutes': neutralMinutes,
        'distractingMinutes': distractingMinutes,
        'preventedDistractions': preventedDistractions,
        'topApps': topApps
            .map((a) => {
                  'appName': a.appName,
                  'packageName': a.packageName,
                  'category': a.category.name,
                  'minutes': a.minutes,
                })
            .toList(),
        'hourlyUsage': hourlyUsage,
        'dailyBreakdown': dailyBreakdown
            .map((d) => {
                  'totalMinutes': d.totalMinutes,
                  'productiveMinutes': d.productiveMinutes,
                  'neutralMinutes': d.neutralMinutes,
                  'distractingMinutes': d.distractingMinutes,
                })
            .toList(),
        'highScreenTaskHours': highScreenTaskHours,
        'lowScreenTaskHours': lowScreenTaskHours,
        'peakUsageHour': peakUsageHour,
        if (trendPercentage != null) 'trendPercentage': trendPercentage,
        'completedTasks': completedTasks,
        'totalTasks': totalTasks,
        'missedTasks': missedTasks,
        'bestStreak': bestStreak,
        'completionRate': completionRate,
        'perfectDays': perfectDays,
        if (dominantRepeatType != null)
          'dominantRepeatType': dominantRepeatType,
        'perTask': perTask
            .map((t) => {
                  'title': t.title,
                  'status': t.status,
                  'streak': t.streak,
                  'timeSlot': t.timeSlot,
                })
            .toList(),
      };
}
