import 'package:flutter/material.dart';
import '../entities/extracted_class.dart';
import '../entities/task.dart';
import '../entities/repeat_type.dart';

/// Ordered list of all day abbreviations used throughout the app.
const _kAllDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Afternoon/evening window for placing homework sessions.
const _kHomeworkWindowStart = 15; // 15:00
const _kHomeworkWindowEnd = 22;   // 22:00

/// Generates repeating [Task]s from a confirmed weekly timetable.
///
/// **Deduplication logic:**
///
/// 1. **Class tasks** – Occurrences that share the same subject, startTime,
///    and endTime are merged into a single [Task] with
///    [RepeatType.custom] and a combined `days` map
///    (e.g. `{"Mon": true, "Tue": true, "Wed": true}`).
///
/// 2. **Study (homework) tasks** – Generated strictly ONCE per unique
///    subject (not per occurrence). The homework hours are taken from
///    the first occurrence that has [ExtractedClass.needsHomework] set.
///
/// 3. **Deterministic IDs** – IDs follow a slug format so that
///    re-importing the same schedule overwrites old tasks instead of
///    creating duplicates:
///      • Class: `"ai_class_<subject>_<HH>_<MM>_<eHH>_<eMM>"`
///      • Study: `"ai_study_<subject>"`  (per session: `"…_<idx>"`)
class GenerateWeeklyTasksUseCase {
  /// Builds a deterministic, URL-safe slug from an arbitrary string.
  static String _slugify(String input) =>
      input.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  Future<List<Task>> call({
    required List<ExtractedClass> classes,
    required List<Task> existingTasks,
    required DateTime importDate,
  }) async {
    final List<Task> result = [];

    // ── 1. Group classes by (subject, startTime, endTime) ─────────────
    //    Key = "subject|HH:MM|HH:MM"
    final Map<String, List<ExtractedClass>> classGroups = {};
    for (final c in classes) {
      final key =
          '${c.subject}|${c.startTime.hour}:${c.startTime.minute}|${c.endTime.hour}:${c.endTime.minute}';
      classGroups.putIfAbsent(key, () => []).add(c);
    }

    // Create ONE class task per group with merged days
    for (final entry in classGroups.entries) {
      final group = entry.value;
      final representative = group.first;
      result.add(_buildClassTask(group, representative, importDate));
    }

    // ── 2. Build a busy-slots map ─────────────────────────────────────
    final busySlots = _buildBusySlots(classes, existingTasks);

    // ── 3. Deduplicate homework by subject ────────────────────────────
    //    Collect the FIRST occurrence per subject that has needsHomework.
    final Map<String, ExtractedClass> homeworkBySubject = {};
    for (final c in classes.where((c) => c.needsHomework)) {
      homeworkBySubject.putIfAbsent(c.subject, () => c);
    }

    // Collect all class-day abbreviations per subject so the scheduler
    // can prefer non-class days.
    final Map<String, Set<String>> classDaysBySubject = {};
    for (final c in classes) {
      classDaysBySubject.putIfAbsent(c.subject, () => {}).add(c.day);
    }

    for (final entry in homeworkBySubject.entries) {
      final subject = entry.key;
      final representative = entry.value;

      final studyTasks = _scheduleHomework(
        subject: subject,
        totalMinutes: (representative.homeworkHoursPerWeek * 60).round(),
        busySlots: busySlots,
        importDate: importDate,
        classDays: classDaysBySubject[subject] ?? {},
      );
      result.addAll(studyTasks);

      // Mark the homework slots as busy so subsequent subjects don't overlap
      for (final t in studyTasks) {
        final start = t.startTime;
        final end = t.endTime;
        if (start != null && end != null) {
          for (final day in _kAllDays) {
            if (t.days[day] == true) {
              busySlots.putIfAbsent(day, () => []);
              busySlots[day]!.add((
                _toMinutes(start),
                _toMinutes(end),
              ));
            }
          }
        }
      }
    }

    return result;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Builds a single merged class [Task] from a group of [ExtractedClass]es
  /// that share the same subject, startTime, and endTime.
  Task _buildClassTask(
    List<ExtractedClass> group,
    ExtractedClass representative,
    DateTime importDate,
  ) {
    // Merge days from every occurrence in the group
    final Map<String, bool> mergedDays = {
      for (final d in _kAllDays)
        d: group.any((c) => c.day == d),
    };

    // Deterministic ID: "ai_class_<subject>_<HH>_<MM>_<eHH>_<eMM>"
    final slug = _slugify(representative.subject);
    final h = representative.startTime.hour.toString().padLeft(2, '0');
    final m = representative.startTime.minute.toString().padLeft(2, '0');
    final eh = representative.endTime.hour.toString().padLeft(2, '0');
    final em = representative.endTime.minute.toString().padLeft(2, '0');
    final id = 'ai_class_${slug}_${h}_${m}_${eh}_$em';

    // Use custom when more than one day is active, weekly otherwise
    final activeDayCount = mergedDays.values.where((v) => v).length;

    return Task(
      id: id,
      title: representative.subject,
      oneTime: false,
      startDate: importDate,
      startTime: representative.startTime,
      endTime: representative.endTime,
      repeatType:
          activeDayCount > 1 ? RepeatType.custom : RepeatType.weekly,
      days: mergedDays,
    );
  }

  /// Collects all occupied (start, end) minute-pairs per day from
  /// both newly imported classes and existing repeating tasks.
  Map<String, List<(int, int)>> _buildBusySlots(
    List<ExtractedClass> classes,
    List<Task> existingTasks,
  ) {
    final Map<String, List<(int, int)>> busy = {};

    // From imported classes
    for (final c in classes) {
      busy.putIfAbsent(c.day, () => []);
      busy[c.day]!.add((_toMinutes(c.startTime), _toMinutes(c.endTime)));
    }

    // From existing repeating tasks that have time slots
    for (final t in existingTasks) {
      if (t.oneTime) continue; // one-off tasks don't block weekly slots
      final start = t.startTime;
      final end = t.endTime;
      if (start == null || end == null) continue;
      for (final day in _kAllDays) {
        if (t.days[day] == true) {
          busy.putIfAbsent(day, () => []);
          busy[day]!.add((_toMinutes(start), _toMinutes(end)));
        }
      }
    }

    return busy;
  }

  /// Returns the list of free (start, end) minute windows on [day]
  /// within the afternoon/evening homework window.
  List<(int, int)> _freeWindowsOnDay(
    String day,
    Map<String, List<(int, int)>> busySlots,
  ) {
    final windowStart = _kHomeworkWindowStart * 60;
    final windowEnd = _kHomeworkWindowEnd * 60;

    // Collect and sort busy intervals that overlap our window
    final busy = (busySlots[day] ?? [])
        .where((s) => s.$2 > windowStart && s.$1 < windowEnd)
        .toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));

    // Walk the window and collect gaps
    final List<(int, int)> free = [];
    int cursor = windowStart;

    for (final slot in busy) {
      final slotStart = slot.$1.clamp(windowStart, windowEnd);
      final slotEnd = slot.$2.clamp(windowStart, windowEnd);
      if (slotStart > cursor) {
        free.add((cursor, slotStart));
      }
      cursor = slotEnd > cursor ? slotEnd : cursor;
    }

    if (cursor < windowEnd) {
      free.add((cursor, windowEnd));
    }

    return free;
  }

  List<Task> _scheduleHomework({
    required String subject,
    required int totalMinutes,
    required Map<String, List<(int, int)>> busySlots,
    required DateTime importDate,
    required Set<String> classDays,
  }) {
    // Max 120 min per session so we don't create a 6-hour block
    const maxSessionMinutes = 120;
    final List<Task> tasks = [];

    // Build a ranked list of candidate days — prefer days that are NOT
    // class days for this subject so the student studies after attending.
    // Non-class days come first, then class days as fallback.
    final nonClassDays =
        _kAllDays.where((d) => !classDays.contains(d)).toList();
    final classOnlyDays =
        _kAllDays.where((d) => classDays.contains(d)).toList();
    final orderedDays = [...nonClassDays, ...classOnlyDays];

    int remaining = totalMinutes;
    int sessionIndex = 0;

    for (final day in orderedDays) {
      if (remaining <= 0) break;

      final windows = _freeWindowsOnDay(day, busySlots);
      for (final window in windows) {
        if (remaining <= 0) break;

        final available = window.$2 - window.$1;
        if (available < 30) continue; // skip windows shorter than 30 min

        final sessionMinutes = remaining.clamp(30, available.clamp(30, maxSessionMinutes));
        final startMin = window.$1;
        final endMin = startMin + sessionMinutes;

        final startTime = TimeOfDay(hour: startMin ~/ 60, minute: startMin % 60);
        final endTime = TimeOfDay(hour: endMin ~/ 60, minute: endMin % 60);

        // Deterministic ID: "ai_study_<subject>" for the first session,
        // "ai_study_<subject>_<idx>" for subsequent sessions.
        final slug = _slugify(subject);
        final id = sessionIndex == 0
            ? 'ai_study_$slug'
            : 'ai_study_${slug}_$sessionIndex';

        tasks.add(Task(
          id: id,
          title: 'Study: $subject',
          oneTime: false,
          startDate: importDate,
          startTime: startTime,
          endTime: endTime,
          repeatType: RepeatType.weekly,
          days: {for (final d in _kAllDays) d: d == day},
        ));

        remaining -= sessionMinutes;
        sessionIndex++;

        // Mark this window as now busy for subsequent subjects
        busySlots.putIfAbsent(day, () => []);
        busySlots[day]!.add((startMin, endMin));
        break; // one session per day is enough
      }
    }

    return tasks;
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;
}

