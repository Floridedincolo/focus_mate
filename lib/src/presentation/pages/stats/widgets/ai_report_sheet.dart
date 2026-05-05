import 'dart:convert';
import 'dart:math' as math;
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import '../../../providers/usage_stats_providers.dart';
import '../../../../domain/entities/task_completion_status.dart';
import '../models/app_category.dart';
import '../models/enriched_usage_stats.dart';
import '../models/hour_annotation.dart';
import 'stats_constants.dart';

/// Multi-page "story" report. Replaces the old bottom sheet.
/// Each page borrows the AppBlock weekly-report layout rhythm:
/// uppercase eyebrow → big headline with accent number → one visual → caption.
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
  final _pageController = PageController();
  int _currentPage = 0;

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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
        'You are a digital wellbeing coach for the focus_mate app. Analyze this user\'s data and provide actionable insights.');
    buf.writeln(
        'IMPORTANT: focus_mate has NO app-limit / screen-time-limit feature. '
        'The ONLY way to limit distractions is to create a task with a blocking template '
        'attached — during that task, specific apps / keywords / websites are blocked '
        '(or only a chosen allow-list is permitted). When suggesting actions, always '
        'phrase them as "create a task with a blocking template covering [hour range]" '
        'or "add [app] to the blocking template of your [task name] task". '
        'Never suggest app timers, daily limits, screen-time caps, or schedules — those don\'t exist.');
    buf.writeln('Give specific time-of-day advice. Reference the exact hour '
        'ranges where the user is most/least productive.');
    buf.writeln('');

    final data = widget.enrichedStats;
    if (data != null) {
      buf.writeln('SCREEN TIME:');
      buf.writeln('- Total: ${formatMinutes(data.totalScreenTimeMinutes)}');
      buf.writeln(
          '- Focus time (during active blocking): ${formatMinutes(data.focusTimeMinutes)}');
      buf.writeln(
          '- Idle/general time: ${formatMinutes(data.idleTimeMinutes)}');
      buf.writeln('');

      buf.writeln('BLOCKING STATS:');
      buf.writeln('- Distractions prevented: ${data.preventedDistractions}');
      buf.writeln('');

      buf.writeln('APP CATEGORIES:');
      buf.writeln('- Productive: ${formatMinutes(data.productiveMinutes)}');
      buf.writeln('- Distracting: ${formatMinutes(data.distractingMinutes)}');
      buf.writeln('- Neutral: ${formatMinutes(data.neutralMinutes)}');
      buf.writeln('');

      if (data.topApps.isNotEmpty) {
        buf.writeln('TOP APPS:');
        for (final app in data.topApps.take(5)) {
          buf.writeln(
              '  * ${app.appName} (${app.category.name}): ${formatMinutes(app.usageMinutes)}');
        }
        buf.writeln('');
      }

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
    buf.writeln('- Perfect days (last 30): ${widget.perfectDays}');
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
    buf.writeln('  "summary": "<one short sentence overall assessment>",');
    buf.writeln(
        '  "insights": ["<screen-time insight>", "<distractions insight>", "<task habits insight>"],');
    buf.writeln(
        '  "tips": ["<tip about screen time trend>", "<tip about task habits>"]');
    buf.writeln('}');
    buf.writeln('');
    buf.writeln(
        'Keep each insight/tip ONE short sentence. Be specific (mention apps, '
        'hours, days). Be encouraging but honest.');

    return buf.toString();
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _ReportShell(
        currentPage: 0,
        pageCount: 1,
        onClose: _close,
        child: const _LoadingPage(),
      );
    }
    if (_error != null) {
      return _ReportShell(
        currentPage: 0,
        pageCount: 1,
        onClose: _close,
        child: _ErrorPage(
          message: _error!,
          onRetry: () {
            setState(() {
              _loading = true;
              _error = null;
            });
            _generateReport();
          },
        ),
      );
    }

    final data = widget.enrichedStats;
    final hasScreenData =
        data != null && data.totalScreenTimeMinutes > 0;

    final ts = widget.taskStats;
    TaskStatusEntry? topTask;
    if (ts.perTask.isNotEmpty) {
      final sorted = [...ts.perTask]
        ..sort((a, b) => b.streak.compareTo(a.streak));
      topTask = sorted.first;
    }

    final pages = <Widget>[
      _CoverPage(score: _score),
      // ── Screen-time pages ────────────────────────────────────────
      if (hasScreenData) _TotalTimePage(stats: data, summary: _summary),
      if (hasScreenData)
        _DailyTimePage(
          stats: data,
          caption: _insights.isNotEmpty ? _insights[0] : null,
        ),
      if (hasScreenData && data.hourlyUsage.isNotEmpty)
        _TypicalDayPage(stats: data),
      if (hasScreenData && data.topApps.isNotEmpty)
        _DistractionsPage(
          stats: data,
          caption: _insights.length > 1 ? _insights[1] : null,
        ),
      if (hasScreenData && data.trendPercentage != null)
        _TrendPage(
          trendPercent: data.trendPercentage!,
          totalMinutes: data.totalScreenTimeMinutes,
          tip: _tips.isNotEmpty ? _tips[0] : null,
        ),
      // ── Task pages ───────────────────────────────────────────────
      _TasksCompletionPage(
        stats: ts,
        caption: _insights.length > 2 ? _insights[2] : null,
      ),
      _TasksHabitsPage(
        stats: ts,
        perfectDays: widget.perfectDays,
        caption: _tips.isNotEmpty ? _tips[0] : null,
      ),
      if (topTask != null)
        _TopTaskPage(
          task: topTask,
          caption: _tips.length > 1 ? _tips[1] : null,
          onDone: _close,
        )
      else
        _OutroPage(score: _score, summary: _summary, onDone: _close),
    ];

    return _ReportShell(
      currentPage: _currentPage,
      pageCount: pages.length,
      onClose: _close,
      child: PageView(
        controller: _pageController,
        onPageChanged: (i) => setState(() => _currentPage = i),
        children: pages,
      ),
    );
  }
}

// ─── Shell ─────────────────────────────────────────────────────────────────

class _ReportShell extends StatelessWidget {
  final int currentPage;
  final int pageCount;
  final VoidCallback onClose;
  final Widget child;

  const _ReportShell({
    required this.currentPage,
    required this.pageCount,
    required this.onClose,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kStatsBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kStatsBg, kStatsCard],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: child),
              // Top bar: close + progress dots
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: onClose,
                    ),
                    Expanded(
                      child: pageCount <= 1
                          ? const SizedBox.shrink()
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(pageCount, (i) {
                                final active = i == currentPage;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 3),
                                  width: active ? 22 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? kStatsAccent
                                        : Colors.white
                                            .withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              }),
                            ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Common page chrome ────────────────────────────────────────────────────

class _PageScaffold extends StatelessWidget {
  final String eyebrow;
  final Widget headline;
  final Widget visual;
  final String? caption;
  final Widget? bottom;

  const _PageScaffold({
    required this.eyebrow,
    required this.headline,
    required this.visual,
    this.caption,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            eyebrow,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          DefaultTextStyle.merge(
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
            child: headline,
          ),
          const SizedBox(height: 32),
          Expanded(child: Center(child: visual)),
          if (caption != null && caption!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              caption!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
          if (bottom != null) ...[
            const SizedBox(height: 16),
            bottom!,
          ],
        ],
      ),
    );
  }
}

Color _scoreColor(int score) {
  if (score >= 7) return kStatsGreen;
  if (score >= 4) return Colors.orangeAccent;
  return Colors.redAccent;
}

// ─── Pages ─────────────────────────────────────────────────────────────────

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: kStatsAccent),
          SizedBox(height: 20),
          Text('Analyzing your week…',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ErrorPage extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorPage({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off,
              size: 56, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry',
                style: TextStyle(color: kStatsAccent)),
          ),
        ],
      ),
    );
  }
}

class _CoverPage extends StatelessWidget {
  final int score;
  const _CoverPage({required this.score});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),
          // Decorative bars background-style
          SizedBox(
            height: 120,
            child: CustomPaint(
              size: const Size(double.infinity, 120),
              painter: _CoverBarsPainter(),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: kStatsAccent2,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 30),
          ),
          const SizedBox(height: 24),
          const Text(
            'Weekly\nReport',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Here\'s how your week went.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: kStatsCard,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                  color: _scoreColor(score).withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Wellbeing score ',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14),
                ),
                Text(
                  '$score',
                  style: TextStyle(
                    color: _scoreColor(score),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '/10',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Swipe to continue →',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CoverBarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    final paint = Paint()..color = kStatsAccent.withValues(alpha: 0.25);
    const barCount = 20;
    final w = size.width / (barCount * 1.4);
    for (int i = 0; i < barCount; i++) {
      final h = 20 + rng.nextDouble() * (size.height - 20);
      final x = i * (w * 1.4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, w, h),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TotalTimePage extends StatelessWidget {
  final EnrichedUsageStats stats;
  final String summary;
  const _TotalTimePage({required this.stats, required this.summary});

  @override
  Widget build(BuildContext context) {
    final total = stats.totalScreenTimeMinutes;
    final productive = stats.productiveMinutes;
    final neutral = stats.neutralMinutes;
    final distracting = stats.distractingMinutes;

    final awakeMinutes = 16 * 60;
    final pct = total <= 0
        ? 0
        : ((total / awakeMinutes) * 100).clamp(0, 100).round();

    return _PageScaffold(
      eyebrow: 'TOTAL SCREEN TIME',
      headline: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
          children: [
            const TextSpan(text: 'You spent in total\n'),
            TextSpan(
                text: formatMinutes(total),
                style: const TextStyle(color: kStatsAccent)),
            const TextSpan(text: ' on your phone last week'),
          ],
        ),
      ),
      visual: SizedBox(
        width: 240,
        height: 240,
        child: CustomPaint(
          painter: _RingPainter(
            productive: productive.toDouble(),
            neutral: neutral.toDouble(),
            distracting: distracting.toDouble(),
            empty: math.max(0, awakeMinutes - total).toDouble(),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.phone_iphone,
                    color: kStatsAccent, size: 24),
                const SizedBox(height: 4),
                Text(
                  formatMinutes(total),
                  style: const TextStyle(
                    color: kStatsAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      caption: summary.isNotEmpty
          ? summary
          : 'Your screen time is about $pct% of the time you were awake.',
    );
  }
}

class _RingPainter extends CustomPainter {
  final double productive, neutral, distracting, empty;
  _RingPainter({
    required this.productive,
    required this.neutral,
    required this.distracting,
    required this.empty,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = productive + neutral + distracting + empty;
    if (total <= 0) return;
    const stroke = 22.0;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: math.min(size.width, size.height) / 2 - stroke / 2,
    );
    double start = -math.pi / 2;
    void seg(double v, Color c) {
      if (v <= 0) return;
      final sweep = (v / total) * 2 * math.pi;
      final p = Paint()
        ..color = c
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, p);
      start += sweep;
    }

    seg(productive, kStatsGreen);
    seg(neutral, kStatsBlue);
    seg(distracting, kStatsPurple);
    seg(empty, Colors.white.withValues(alpha: 0.06));
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.productive != productive ||
      oldDelegate.neutral != neutral ||
      oldDelegate.distracting != distracting ||
      oldDelegate.empty != empty;
}

class _DailyTimePage extends StatelessWidget {
  final EnrichedUsageStats stats;
  final String? caption;
  const _DailyTimePage({required this.stats, this.caption});

  @override
  Widget build(BuildContext context) {
    final breakdown = stats.dailyCategoryBreakdown;
    final daily = stats.dailyUsage;
    final days = breakdown.length >= 7
        ? breakdown.take(7).toList()
        : List.generate(
            7,
            (i) => DayCategoryBreakdown(
              totalMinutes: i < daily.length ? daily[i] : 0,
            ),
          );

    final totalMin =
        days.fold<int>(0, (s, d) => s + d.totalMinutes);
    final activeDays = days.where((d) => d.totalMinutes > 0).length;
    final avg = activeDays > 0 ? totalMin ~/ activeDays : 0;

    int lightestIdx = 0;
    for (int i = 1; i < days.length; i++) {
      if (days[i].totalMinutes < days[lightestIdx].totalMinutes ||
          days[lightestIdx].totalMinutes == 0) {
        lightestIdx = i;
      }
    }
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final lightestLabel = dayLabels[lightestIdx];

    return _PageScaffold(
      eyebrow: 'AVG SCREEN TIME',
      headline: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
          children: [
            const TextSpan(text: 'Your daily screen time\n'),
            TextSpan(
                text: formatMinutes(avg),
                style: const TextStyle(color: kStatsAccent)),
          ],
        ),
      ),
      visual: SizedBox(
        height: 220,
        child: _DailyBars(days: days),
      ),
      caption: caption ??
          (totalMin == 0
              ? null
              : '$lightestLabel was your lightest day. Aim for more like that.'),
    );
  }
}

class _DailyBars extends StatelessWidget {
  final List<DayCategoryBreakdown> days;
  const _DailyBars({required this.days});

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxMin =
        days.fold<int>(0, (m, d) => d.totalMinutes > m ? d.totalMinutes : m);
    final scale = maxMin == 0 ? 1.0 : 160.0 / maxMin;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final d = days[i];
        final pH = d.productiveMinutes * scale;
        final nH = d.neutralMinutes * scale;
        final dH = d.distractingMinutes * scale;
        final fallback = (d.totalMinutes -
                d.productiveMinutes -
                d.neutralMinutes -
                d.distractingMinutes) *
            scale;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  d.totalMinutes > 0
                      ? formatMinutes(d.totalMinutes)
                      : '',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (dH > 0)
                          Container(height: dH, color: kStatsPurple),
                        if (nH > 0)
                          Container(height: nH, color: kStatsBlue),
                        if (pH > 0)
                          Container(height: pH, color: kStatsGreen),
                        if (pH == 0 && nH == 0 && dH == 0 && fallback > 0)
                          Container(height: fallback, color: kStatsBlue),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dayLabels[i],
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _DistractionsPage extends StatelessWidget {
  final EnrichedUsageStats stats;
  final String? caption;
  const _DistractionsPage({required this.stats, this.caption});

  @override
  Widget build(BuildContext context) {
    final distractors = stats.topApps
        .where((a) => a.category == AppCategory.distracting)
        .toList();
    final top = distractors.isNotEmpty ? distractors.first : stats.topApps.first;
    final others = (distractors.isNotEmpty ? distractors : stats.topApps)
        .where((a) => a.packageName != top.packageName)
        .take(4)
        .toList();

    return _PageScaffold(
      eyebrow: 'DISTRACTIONS',
      headline: const Text(
          'Everyone has their digital distractions.\nThese are yours.'),
      visual: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: kStatsCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: kStatsAccent.withValues(alpha: 0.4), width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              top.appName.isNotEmpty
                  ? top.appName.substring(0, 1).toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            top.appName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Total time: ${formatMinutes(top.usageMinutes)}',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
          ),
          if (others.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              'Other top apps',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: others
                  .map((a) => Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: kStatsCard,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white
                                      .withValues(alpha: 0.1),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                a.appName.isNotEmpty
                                    ? a.appName
                                        .substring(0, 1)
                                        .toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatMinutes(a.usageMinutes),
                              style: TextStyle(
                                color:
                                    Colors.white.withValues(alpha: 0.6),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
      caption: caption,
    );
  }
}

class _TrendPage extends StatelessWidget {
  final double trendPercent; // negative = improvement
  final int totalMinutes;
  final String? tip;
  const _TrendPage({
    required this.trendPercent,
    required this.totalMinutes,
    this.tip,
  });

  @override
  Widget build(BuildContext context) {
    final improved = trendPercent <= 0;
    final color = improved ? kStatsGreen : kStatsRed;
    final pctText = '${trendPercent.abs().toStringAsFixed(0)}%';

    return _PageScaffold(
      eyebrow: 'TREND',
      headline: Text(
        improved
            ? 'Nice! You hit the brakes\nthis week 🙌'
            : 'Screen time crept up\nthis week',
      ),
      visual: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              improved ? Icons.south_east : Icons.north_east,
              color: Colors.white,
              size: 44,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '${improved ? "−" : "+"}$pctText',
            style: TextStyle(
              color: color,
              fontSize: 56,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            improved
                ? 'less screen time than last week'
                : 'more screen time than last week',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
      caption: tip,
    );
  }
}

Color _completionColor(int pct) {
  if (pct >= 70) return kStatsGreen;
  if (pct >= 40) return Colors.orangeAccent;
  return kStatsRed;
}

class _TasksCompletionPage extends StatelessWidget {
  final TaskStatsData stats;
  final String? caption;
  const _TasksCompletionPage({required this.stats, this.caption});

  @override
  Widget build(BuildContext context) {
    final pct = (stats.completionRate * 100).round();
    return _PageScaffold(
      eyebrow: 'TASKS',
      headline: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
          children: [
            const TextSpan(text: 'You completed\n'),
            TextSpan(
              text: '${stats.completed}/${stats.total}',
              style: const TextStyle(color: kStatsAccent),
            ),
            const TextSpan(text: ' tasks this week'),
          ],
        ),
      ),
      visual: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$pct%',
            style: TextStyle(
              color: _completionColor(pct),
              fontSize: 80,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'completion rate',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
          ),
          const SizedBox(height: 32),
          SizedBox(height: 130, child: _TaskRateBars(rates: stats.dailyRates)),
        ],
      ),
      caption: caption ??
          (stats.total == 0
              ? 'No tasks scheduled this week.'
              : '${stats.missed} missed, ${stats.total - stats.completed - stats.missed} still upcoming.'),
    );
  }
}

class _TasksHabitsPage extends StatelessWidget {
  final TaskStatsData stats;
  final int perfectDays;
  final String? caption;
  const _TasksHabitsPage({
    required this.stats,
    required this.perfectDays,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final showStreak = stats.bestStreak >= perfectDays;
    final headlineNumber = showStreak ? stats.bestStreak : perfectDays;
    final headlineLabel = showStreak ? 'days streak' : 'perfect days';
    final headlineIntro = showStreak
        ? 'Your best run was'
        : 'You had';

    return _PageScaffold(
      eyebrow: 'HABITS',
      headline: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
          children: [
            TextSpan(text: '$headlineIntro\n'),
            TextSpan(
              text: '$headlineNumber',
              style: const TextStyle(color: kStatsAccent),
            ),
            TextSpan(text: ' $headlineLabel'),
          ],
        ),
      ),
      visual: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 130,
            height: 130,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kStatsAccent, kStatsAccent2],
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              showStreak
                  ? Icons.local_fire_department
                  : Icons.star_rounded,
              color: Colors.white,
              size: 70,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TaskStat(
                  icon: Icons.local_fire_department,
                  value: '${stats.bestStreak}',
                  label: 'best streak'),
              const SizedBox(width: 28),
              _TaskStat(
                  icon: Icons.star_rounded,
                  value: '$perfectDays',
                  label: 'perfect days'),
              const SizedBox(width: 28),
              _TaskStat(
                  icon: Icons.cancel_outlined,
                  value: '${stats.missed}',
                  label: 'missed'),
            ],
          ),
        ],
      ),
      caption: caption,
    );
  }
}

class _TopTaskPage extends StatelessWidget {
  final TaskStatusEntry task;
  final String? caption;
  final VoidCallback onDone;
  const _TopTaskPage({
    required this.task,
    required this.onDone,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (task.status) {
      TaskCompletionStatus.completed => 'Completed today ✓',
      TaskCompletionStatus.upcoming => 'Up next today',
      TaskCompletionStatus.missed => 'Missed today',
      TaskCompletionStatus.hidden => 'Off today',
    };
    final statusColor = switch (task.status) {
      TaskCompletionStatus.completed => kStatsGreen,
      TaskCompletionStatus.upcoming => kStatsBlue,
      TaskCompletionStatus.missed => kStatsRed,
      TaskCompletionStatus.hidden => Colors.white54,
    };

    return _PageScaffold(
      eyebrow: 'YOUR ANCHOR TASK',
      headline:
          const Text('The task that kept you\non track this week'),
      visual: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: kStatsCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: kStatsAccent2.withValues(alpha: 0.5), width: 2),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.task_alt,
                color: kStatsAccent2, size: 44),
          ),
          const SizedBox(height: 20),
          Text(
            task.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (task.timeSlot.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              task.timeSlot,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: kStatsAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department,
                        color: kStatsAccent, size: 16),
                    const SizedBox(width: 6),
                    Text('${task.streak}-day streak',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
      caption: caption,
      bottom: _DoneButton(onDone: onDone),
    );
  }
}

class _OutroPage extends StatelessWidget {
  final int score;
  final String summary;
  final VoidCallback onDone;
  const _OutroPage({
    required this.score,
    required this.summary,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      eyebrow: 'WRAP-UP',
      headline: const Text('That\'s your week.'),
      visual: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$score',
              style: TextStyle(
                color: _scoreColor(score),
                fontSize: 96,
                fontWeight: FontWeight.w800,
                height: 1,
              )),
          Text('/10 wellbeing',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
        ],
      ),
      caption: summary.isNotEmpty ? summary : null,
      bottom: _DoneButton(onDone: onDone),
    );
  }
}

class _DoneButton extends StatelessWidget {
  final VoidCallback onDone;
  const _DoneButton({required this.onDone});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: kStatsAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onDone,
        child: const Text('Done',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ─── TYPICAL DAY (hourly bars + peak hour) ─────────────────────────────────

class _TypicalDayPage extends StatelessWidget {
  final EnrichedUsageStats stats;
  const _TypicalDayPage({required this.stats});

  @override
  Widget build(BuildContext context) {
    int peakHour = 0;
    for (int i = 1; i < stats.hourlyUsage.length; i++) {
      if (stats.hourlyUsage[i] > stats.hourlyUsage[peakHour]) peakHour = i;
    }
    final next = (peakHour + 1) % 24;
    String hh(int h) => '${h.toString().padLeft(2, '0')}:00';

    return _PageScaffold(
      eyebrow: 'TYPICAL DAY',
      headline: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
          children: [
            const TextSpan(text: 'You\'re on the phone\nthe most around\n'),
            TextSpan(
              text: '${hh(peakHour)} – ${hh(next)}',
              style: const TextStyle(color: kStatsAccent),
            ),
          ],
        ),
      ),
      visual: SizedBox(
        height: 220,
        child: _HourlyBars(hourly: stats.hourlyUsage, peakHour: peakHour),
      ),
      caption:
          'Try a task with a blocking template covering this hour to keep distracting apps out.',
    );
  }
}

class _HourlyBars extends StatelessWidget {
  final List<int> hourly;
  final int peakHour;
  const _HourlyBars({required this.hourly, required this.peakHour});

  @override
  Widget build(BuildContext context) {
    final list = hourly.length >= 24 ? hourly : List.filled(24, 0);
    final maxV = list.fold<int>(0, (m, v) => v > m ? v : m);
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(24, (h) {
              final v = list[h];
              final hgt = maxV == 0 ? 0.0 : (v / maxV) * 180.0;
              final isPeak = h == peakHour;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Container(
                    height: hgt < 2 ? 2 : hgt,
                    decoration: BoxDecoration(
                      gradient: isPeak
                          ? const LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [kStatsAccent, kStatsRed],
                            )
                          : null,
                      color: isPeak ? null : kStatsAccent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final l in ['0', '6', '12', '18', '23'])
                Text(l,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }
}


class _TaskRateBars extends StatelessWidget {
  final List<double> rates; // 0..1, length 7, Mon-Sun
  const _TaskRateBars({required this.rates});

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final r = i < rates.length ? rates[i].clamp(0.0, 1.0) : 0.0;
        final h = (r * 80).clamp(2.0, 80.0);
        final color = r >= 0.7
            ? kStatsGreen
            : r >= 0.4
                ? Colors.orangeAccent
                : (r > 0 ? kStatsRed : Colors.white24);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: h.toDouble(),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dayLabels[i],
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _TaskStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _TaskStat(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: kStatsAccent2, size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
      ],
    );
  }
}
