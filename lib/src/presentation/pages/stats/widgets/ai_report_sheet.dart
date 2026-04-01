import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import '../../../providers/usage_stats_providers.dart';
import '../models/enriched_usage_stats.dart';
import '../models/hour_annotation.dart';
import 'stats_constants.dart';

/// Feature 6: Enhanced AI report bottom sheet with Gemini integration.
/// Includes enriched context: categories, correlations, repeat patterns.
class AiReportSheet extends StatefulWidget {
  final EnrichedUsageStats? enrichedStats;
  final TaskStatsData taskStats;
  final int perfectDays;

  const AiReportSheet({
    super.key,
    required this.enrichedStats,
    required this.taskStats,
    required this.perfectDays,
  });

  @override
  State<AiReportSheet> createState() => _AiReportSheetState();
}

class _AiReportSheetState extends State<AiReportSheet> {
  bool _loading = true;
  String? _error;
  int _score = 0;
  String _summary = '';
  List<String> _insights = [];
  List<String> _tips = [];

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  Future<void> _generateReport() async {
    try {
      final prompt = _buildPrompt();
      final model = FirebaseAI.vertexAI().generativeModel(
        model: 'gemini-2.0-flash',
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.4,
        ),
      );

      final response = await model
          .generateContent([Content.text(prompt)]).timeout(
              const Duration(seconds: 30));

      final text = response.text ?? '';
      final json = jsonDecode(text) as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _score = (json['score'] as num?)?.toInt() ?? 5;
          _summary = json['summary'] as String? ?? '';
          _insights = (json['insights'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          _tips = (json['tips'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not generate report. Please try again.';
          _loading = false;
        });
      }
    }
  }

  String _buildPrompt() {
    final buf = StringBuffer();
    buf.writeln(
        'You are a digital wellbeing coach. Analyze this user\'s data and provide actionable insights.');
    buf.writeln('Give specific time-of-day advice. Reference the exact hour '
        'ranges where the user is most/least productive. Suggest which '
        'distracting apps to block during which task time slots.');
    buf.writeln('');

    final data = widget.enrichedStats;
    if (data != null) {
      buf.writeln('SCREEN TIME:');
      buf.writeln('- Total: ${formatMinutes(data.totalScreenTimeMinutes)}');
      buf.writeln('- Focus time (during active blocking): ${formatMinutes(data.focusTimeMinutes)}');
      buf.writeln('- Idle/general time: ${formatMinutes(data.idleTimeMinutes)}');
      buf.writeln('');

      // Feature 1: Blocking stats
      buf.writeln('BLOCKING STATS:');
      buf.writeln('- Distractions prevented: ${data.preventedDistractions}');
      buf.writeln('');

      // Feature 3: App categories
      buf.writeln('APP CATEGORIES:');
      buf.writeln('- Productive: ${formatMinutes(data.productiveMinutes)}');
      buf.writeln('- Distracting: ${formatMinutes(data.distractingMinutes)}');
      buf.writeln('- Neutral: ${formatMinutes(data.neutralMinutes)}');
      buf.writeln('');

      // Top apps
      if (data.topApps.isNotEmpty) {
        buf.writeln('TOP APPS:');
        for (final app in data.topApps.take(5)) {
          buf.writeln(
              '  * ${app.appName} (${app.category.name}): ${formatMinutes(app.usageMinutes)}');
        }
        buf.writeln('');
      }

      // Feature 2: Time correlations
      final highTaskHours = data.hourAnnotations
          .where((a) => a.hasTask && a.screenTimeLevel == ScreenTimeLevel.high)
          .map((a) => '${a.hour}:00')
          .toList();
      final lowTaskHours = data.hourAnnotations
          .where((a) => a.hasTask && a.screenTimeLevel == ScreenTimeLevel.low)
          .map((a) => '${a.hour}:00')
          .toList();

      buf.writeln('TIME CORRELATIONS:');
      buf.writeln('- Hours with tasks + HIGH screen time (distracted): '
          '${highTaskHours.isEmpty ? "none" : highTaskHours.join(", ")}');
      buf.writeln('- Hours with tasks + LOW screen time (focused): '
          '${lowTaskHours.isEmpty ? "none" : lowTaskHours.join(", ")}');

      // Peak hour
      int peakHour = 0;
      for (int i = 1; i < data.hourlyUsage.length; i++) {
        if (data.hourlyUsage[i] > data.hourlyUsage[peakHour]) peakHour = i;
      }
      buf.writeln('- Peak usage hour: $peakHour:00');
      buf.writeln('');
    }

    buf.writeln('TASKS:');
    buf.writeln(
        '- Completed: ${widget.taskStats.completed} / ${widget.taskStats.total}');
    buf.writeln('- Missed: ${widget.taskStats.missed}');
    buf.writeln('- Best streak: ${widget.taskStats.bestStreak} days');
    buf.writeln(
        '- Completion rate: ${(widget.taskStats.completionRate * 100).round()}%');

    // Feature 4: Perfect days
    buf.writeln('- Perfect days (last 30): ${widget.perfectDays}');

    // Feature 6: Dominant repeat type
    if (widget.taskStats.dominantRepeatType != null) {
      buf.writeln(
          '- Most common schedule pattern: ${widget.taskStats.dominantRepeatType!.name}');
    }

    if (widget.taskStats.perTask.isNotEmpty) {
      buf.writeln('- Per-task breakdown:');
      for (final t in widget.taskStats.perTask) {
        buf.writeln(
            '  * "${t.title}" — ${t.status.name}, streak: ${t.streak}${t.timeSlot.isNotEmpty ? ', time: ${t.timeSlot}' : ''}');
      }
    }

    buf.writeln('');
    buf.writeln('Respond in this exact JSON format:');
    buf.writeln('{');
    buf.writeln(
        '  "score": <1-10 integer, overall productivity/wellbeing score>,');
    buf.writeln('  "summary": "<one sentence overall assessment>",');
    buf.writeln(
        '  "insights": ["<insight 1>", "<insight 2>", "<insight 3>"],');
    buf.writeln(
        '  "tips": ["<actionable tip 1>", "<actionable tip 2>"]');
    buf.writeln('}');
    buf.writeln('');
    buf.writeln(
        'Keep insights short (1 sentence each). Tips should be specific, '
        'actionable, and reference times/apps. Be encouraging but honest.');

    return buf.toString();
  }

  Color _scoreColor(int score) {
    if (score >= 7) return kStatsGreen;
    if (score >= 4) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: kStatsCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: kStatsAccent, size: 22),
                  SizedBox(width: 8),
                  Text('AI Wellbeing Report',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 24),

              if (_loading) ...[
                const SizedBox(height: 40),
                const Center(
                    child: CircularProgressIndicator(color: kStatsAccent)),
                const SizedBox(height: 16),
                Center(
                  child: Text('Analyzing your data...',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14)),
                ),
                const SizedBox(height: 40),
              ] else if (_error != null) ...[
                const SizedBox(height: 20),
                Icon(Icons.cloud_off,
                    size: 48,
                    color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14)),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                      _generateReport();
                    },
                    child: const Text('Retry',
                        style: TextStyle(color: kStatsAccent)),
                  ),
                ),
              ] else ...[
                // Score
                Center(
                  child: Column(
                    children: [
                      Text('$_score',
                          style: TextStyle(
                              color: _scoreColor(_score),
                              fontSize: 56,
                              fontWeight: FontWeight.w800)),
                      Text('/ 10',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_summary.isNotEmpty)
                  Center(
                    child: Text(_summary,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                            height: 1.4)),
                  ),
                const SizedBox(height: 24),

                // Insights
                if (_insights.isNotEmpty) ...[
                  Text('INSIGHTS',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1)),
                  const SizedBox(height: 10),
                  ...(_insights.map((insight) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.lightbulb_outline,
                                  size: 16, color: kStatsAccent),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(insight,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      height: 1.4)),
                            ),
                          ],
                        ),
                      ))),
                  const SizedBox(height: 16),
                ],

                // Tips
                if (_tips.isNotEmpty) ...[
                  Text('TIPS',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1)),
                  const SizedBox(height: 10),
                  ...(_tips.map((tip) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kStatsAccent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: kStatsAccent.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.tips_and_updates,
                                size: 16, color: kStatsAccent2),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(tip,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      height: 1.4)),
                            ),
                          ],
                        ),
                      ))),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}
