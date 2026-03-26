// filepath: lib/src/domain/usecases/suggest_meeting_algorithmic_use_case.dart
import 'package:flutter/material.dart';

import '../entities/meeting_location.dart';
import '../entities/meeting_proposal.dart';
import '../entities/task.dart';

export '../entities/meeting_proposal.dart' show ProposalSource;

/// Finds up to [maxProposals] common free time-slots for a group of users
/// using a pure intersection algorithm — **no external dependencies**.
class SuggestMeetingAlgorithmicUseCase {
  const SuggestMeetingAlgorithmicUseCase();

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

  _Interval? _taskToInterval(Task task, DateTime date) {
    final st = task.startTime;
    final et = task.endTime;
    if (st == null || et == null) return null;

    if (!_taskOccursOnDate(task, date)) return null;

    final start = date.copyWith(
        hour: st.hour, minute: st.minute, second: 0, millisecond: 0, microsecond: 0);
    var end = date.copyWith(
        hour: et.hour, minute: et.minute, second: 0, millisecond: 0, microsecond: 0);

    if (end.isBefore(start)) end = end.add(const Duration(days: 1));

    return _Interval(start, end);
  }

  bool _taskOccursOnDate(Task task, DateTime date) {
    if (task.archived) return false;

    if (task.oneTime) {
      return task.startDate.year == date.year &&
          task.startDate.month == date.month &&
          task.startDate.day == date.day;
    }

    const weekdayKeys = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final key = weekdayKeys[date.weekday - 1];
    return task.days[key] ?? false;
  }

  List<_Interval> _mergeIntervals(List<_Interval> sorted) {
    if (sorted.isEmpty) return [];
    final result = [sorted.first];
    for (var i = 1; i < sorted.length; i++) {
      final last = result.last;
      final cur = sorted[i];
      if (!cur.start.isAfter(last.end)) {
        result[result.length - 1] =
            _Interval(last.start, cur.end.isAfter(last.end) ? cur.end : last.end);
      } else {
        result.add(cur);
      }
    }
    return result;
  }

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
      slotStart = slotEnd;
    }
  }
}

/// A simple closed interval [start, end).
class _Interval {
  final DateTime start;
  final DateTime end;
  const _Interval(this.start, this.end);
}
