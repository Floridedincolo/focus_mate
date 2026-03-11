// filepath: lib/src/domain/usecases/suggest_meeting_algorithmic_use_case.dart
import 'package:flutter/material.dart';

import '../entities/meeting_location.dart';
import '../entities/meeting_proposal.dart';
import '../entities/task.dart';

export '../entities/meeting_proposal.dart' show ProposalSource;

/// Finds up to [maxProposals] common free time-slots for a group of users
/// using a pure intersection algorithm — **no external dependencies**.
///
/// ### Algorithm overview
/// 1. For every member, build a list of "busy intervals" from their [Task]
///    list (only tasks that have both [Task.startTime] and [Task.endTime] set
///    and are scheduled on [targetDate]).
/// 2. Merge all members' busy intervals into a single sorted, non-overlapping
///    "group busy" list.
/// 3. Walk the gaps between busy intervals within the configurable day window
///    ([dayStart] – [dayEnd]).  Each gap ≥ [meetingDurationMinutes] becomes a
///    candidate proposal, cropped to exactly [meetingDurationMinutes].
/// 4. Return the first [maxProposals] candidates, each carrying a generic
///    [MeetingLocation.tbd()] location.
///
/// ### Example usage
/// ```dart
/// final useCase = SuggestMeetingAlgorithmicUseCase();
/// final proposals = useCase(
///   memberSchedules: [alicesTasks, bobsTasks, carlasTasks],
///   meetingDurationMinutes: 60,
///   targetDate: DateTime(2026, 3, 15),
/// );
/// ```
class SuggestMeetingAlgorithmicUseCase {
  const SuggestMeetingAlgorithmicUseCase();

  /// [dayStart] and [dayEnd] define the window in which meetings are allowed.
  /// Defaults to 08:00 – 22:00.
  List<MeetingProposal> call({
    required List<List<Task>> memberSchedules,
    required int meetingDurationMinutes,
    required DateTime targetDate,
    TimeOfDay dayStart = const TimeOfDay(hour: 8, minute: 0),
    TimeOfDay dayEnd = const TimeOfDay(hour: 22, minute: 0),
    int maxProposals = 3,
  }) {
    assert(memberSchedules.isNotEmpty, 'Provide at least one member schedule.');
    assert(meetingDurationMinutes > 0, 'Duration must be positive.');

    final date = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final windowStart = date.copyWith(
        hour: dayStart.hour, minute: dayStart.minute, second: 0, millisecond: 0, microsecond: 0);
    final windowEnd = date.copyWith(
        hour: dayEnd.hour, minute: dayEnd.minute, second: 0, millisecond: 0, microsecond: 0);

    // ── 1. Collect all busy intervals across every member ─────────────────
    final List<_Interval> allBusy = [];
    for (final tasks in memberSchedules) {
      for (final task in tasks) {
        final interval = _taskToInterval(task, date);
        if (interval != null) allBusy.add(interval);
      }
    }

    // ── 2. Sort and merge overlapping busy intervals ──────────────────────
    allBusy.sort((a, b) => a.start.compareTo(b.start));
    final merged = _mergeIntervals(allBusy);

    // ── 3. Walk the gaps and collect free slots ───────────────────────────
    final meetingDuration = Duration(minutes: meetingDurationMinutes);
    final proposals = <MeetingProposal>[];
    DateTime cursor = windowStart;

    for (final busy in merged) {
      if (proposals.length >= maxProposals) break;

      // Gap between cursor and the start of this busy block.
      if (busy.start.isAfter(cursor)) {
        final gapEnd =
            busy.start.isBefore(windowEnd) ? busy.start : windowEnd;
        _extractSlots(
          from: cursor,
          to: gapEnd,
          duration: meetingDuration,
          proposals: proposals,
          maxProposals: maxProposals,
        );
      }

      // Advance cursor past this busy block.
      if (busy.end.isAfter(cursor)) cursor = busy.end;
    }

    // Trailing gap (after the last busy block until dayEnd).
    if (proposals.length < maxProposals && cursor.isBefore(windowEnd)) {
      _extractSlots(
        from: cursor,
        to: windowEnd,
        duration: meetingDuration,
        proposals: proposals,
        maxProposals: maxProposals,
      );
    }

    return proposals;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Converts a [Task] to an [_Interval] on [date].
  /// Returns null if the task has no time info or does not occur on [date].
  _Interval? _taskToInterval(Task task, DateTime date) {
    final st = task.startTime;
    final et = task.endTime;
    if (st == null || et == null) return null;

    // Check the task is active on `date`.
    if (!_taskOccursOnDate(task, date)) return null;

    final start = date.copyWith(
        hour: st.hour, minute: st.minute, second: 0, millisecond: 0, microsecond: 0);
    var end = date.copyWith(
        hour: et.hour, minute: et.minute, second: 0, millisecond: 0, microsecond: 0);

    // Handle midnight-crossing tasks gracefully (end clipped to same day).
    if (end.isBefore(start)) end = end.add(const Duration(days: 1));

    return _Interval(start, end);
  }

  /// Returns true when [task] is scheduled on [date] according to its
  /// recurrence settings. One-time tasks are matched by [Task.startDate].
  bool _taskOccursOnDate(Task task, DateTime date) {
    if (task.archived) return false;

    if (task.oneTime) {
      return task.startDate.year == date.year &&
          task.startDate.month == date.month &&
          task.startDate.day == date.day;
    }

    // For repeating tasks, use the `days` map (keys: 'Mon', 'Tue', …).
    const weekdayKeys = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final key = weekdayKeys[date.weekday - 1]; // DateTime.weekday: 1=Mon
    return task.days[key] ?? false;
  }

  /// Merges a **sorted** list of intervals into a non-overlapping list.
  List<_Interval> _mergeIntervals(List<_Interval> sorted) {
    if (sorted.isEmpty) return [];
    final result = [sorted.first];
    for (var i = 1; i < sorted.length; i++) {
      final last = result.last;
      final cur = sorted[i];
      if (!cur.start.isAfter(last.end)) {
        // Overlapping or adjacent — extend.
        result[result.length - 1] =
            _Interval(last.start, cur.end.isAfter(last.end) ? cur.end : last.end);
      } else {
        result.add(cur);
      }
    }
    return result;
  }

  /// Fills [proposals] with back-to-back [duration]-long slots within [from]–[to].
  void _extractSlots({
    required DateTime from,
    required DateTime to,
    required Duration duration,
    required List<MeetingProposal> proposals,
    required int maxProposals,
  }) {
    var slotStart = from;
    while (proposals.length < maxProposals) {
      final slotEnd = slotStart.add(duration);
      if (slotEnd.isAfter(to)) break;
      proposals.add(MeetingProposal(
        startTime: slotStart,
        endTime: slotEnd,
        location: const MeetingLocation.tbd(),
        source: ProposalSource.algorithmic,
      ));
      slotStart = slotEnd; // non-overlapping; adjust if you want gaps
    }
  }
}

/// A simple closed interval [start, end).
class _Interval {
  final DateTime start;
  final DateTime end;
  const _Interval(this.start, this.end);
}

