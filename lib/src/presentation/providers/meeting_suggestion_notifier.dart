import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/service_locator.dart';
import '../../data/datasources/location_search_service.dart';
import '../../data/datasources/transit_route_service.dart';
import '../../domain/entities/meeting_location.dart';
import '../../domain/entities/meeting_proposal.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/friend_repository.dart';
import '../../domain/repositories/user_location_repository.dart';
import '../../domain/usecases/suggest_meeting_ai_use_case.dart';
import '../../domain/usecases/suggest_meeting_algorithmic_use_case.dart';
import '../models/meeting_suggestion_state.dart';
import 'task_providers.dart';

/// Drives the multi-step Plan Meeting wizard.
class MeetingSuggestionNotifier extends Notifier<MeetingSuggestionState> {
  @override
  MeetingSuggestionState build() => const MeetingSuggestionState();

  // ── Step transitions ──────────────────────────────────────────────────

  void reset() => state = const MeetingSuggestionState();

  void selectFriends(List<String> uids, List<String> names) {
    state = state.copyWith(
      selectedFriendUids: uids,
      selectedFriendNames: names,
      step: MeetingSuggestionStep.configure,
    );
  }

  void configure({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required int durationMinutes,
    required ProposalSource source,
  }) {
    state = state.copyWith(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      meetingDurationMinutes: durationMinutes,
      proposalSource: source,
      step: MeetingSuggestionStep.loading,
    );
    _runSuggestion();
  }

  void goBack() {
    switch (state.step) {
      case MeetingSuggestionStep.configure:
        state = state.copyWith(step: MeetingSuggestionStep.selectFriends);
        break;
      case MeetingSuggestionStep.results:
      case MeetingSuggestionStep.error:
        state = state.copyWith(step: MeetingSuggestionStep.configure);
        break;
      default:
        break;
    }
  }

  // ── Business logic ────────────────────────────────────────────────────

  static const _maxProposals = 5;
  static const _maxPerDay = 8;

  Future<void> _runSuggestion() async {
    try {
      final tasksAsync = ref.read(tasksStreamProvider);
      final myTasks = tasksAsync.valueOrNull ?? <Task>[];

      final friendRepo = getIt<FriendRepository>();
      final friendSchedules = <List<Task>>[];
      for (final friendUid in state.selectedFriendUids) {
        try {
          final tasks = await friendRepo.getTasksForUser(friendUid);
          friendSchedules.add(
            tasks
                .where((t) =>
                    !t.archived &&
                    t.startTime != null &&
                    t.endTime != null)
                .toList(),
          );
        } catch (e) {
          if (kDebugMode) debugPrint('Failed to fetch tasks for $friendUid: $e');
          friendSchedules.add(<Task>[]);
        }
      }

      final memberSchedules = <List<Task>>[
        myTasks
            .where((t) =>
                !t.archived &&
                t.startTime != null &&
                t.endTime != null)
            .toList(),
        ...friendSchedules,
      ];

      // ── Collect member locations (current user + friends) ──
      final memberLocations = await _collectMemberLocations();

      final rangeStart = state.rangeStart ?? DateTime.now();
      final rangeEnd = state.rangeEnd ?? rangeStart.add(const Duration(days: 14));
      final startDate = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
      final endDate = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);
      final totalDays = endDate.difference(startDate).inDays + 1;
      final homes = _extractHomes(memberLocations);

      final allCandidates = <MeetingProposal>[];

      for (int dayOffset = 0; dayOffset < totalDays; dayOffset++) {
        final targetDate = startDate.add(Duration(days: dayOffset));

        try {
          final List<MeetingProposal> dayProposals;

          if (state.proposalSource == ProposalSource.algorithmic) {
            final useCase = getIt<SuggestMeetingAlgorithmicUseCase>();
            dayProposals = useCase(
              memberSchedules: memberSchedules,
              meetingDurationMinutes: state.meetingDurationMinutes,
              targetDate: targetDate,
              maxProposals: _maxPerDay,
            );
          } else {
            final useCase = getIt<SuggestMeetingAiUseCase>();
            dayProposals = await useCase(
              memberSchedules: memberSchedules,
              meetingDurationMinutes: state.meetingDurationMinutes,
              targetDate: targetDate,
              maxProposals: _maxPerDay,
              memberLocations: memberLocations,
            );
          }

          allCandidates.addAll(dayProposals);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('No slots on ${targetDate.toIso8601String()}: $e');
          }
        }
      }

      // ── Score & rank candidates ──
      // Filter out proposals outside 10:00–22:00 unless no normal-hour
      // alternatives exist at all.
      final normalHour = allCandidates
          .where((p) => p.startTime.hour >= 10 && p.startTime.hour < 22)
          .toList();
      final pool = normalHour.isNotEmpty ? normalHour : allCandidates;

      // Score each proposal (higher = better).
      final scored = pool.map((p) {
        final score = _scoreProposal(p, memberSchedules, homes, startDate);
        return (proposal: p, score: score);
      }).toList();

      scored.sort((a, b) => b.score.compareTo(a.score));

      final topProposals =
          scored.take(_maxProposals).map((s) => s.proposal).toList();

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final allMemberUids = [
        if (currentUid != null) currentUid,
        ...state.selectedFriendUids,
      ];

      // ── Resolve locations for algorithmic proposals (TBD → real place) ──
      final resolvedProposals = await _resolveAlgorithmicLocations(
        topProposals,
        memberLocations,
        memberSchedules,
      );

      // ── Adjust start times based on real travel time ──
      final adjusted = await _adjustByTransitTime(
        resolvedProposals,
        memberSchedules,
        homes,
      );

      final enrichedProposals = adjusted
          .map((p) => p.copyWith(groupMemberUids: allMemberUids))
          .toList();

      state = state.copyWith(
        proposals: enrichedProposals,
        step: MeetingSuggestionStep.results,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString(),
        step: MeetingSuggestionStep.error,
      );
    }
  }

  /// Reads home locations for the current user (SharedPrefs) and friends (Firestore).
  Future<List<(MeetingLocation? home, MeetingLocation? work)>>
      _collectMemberLocations() async {
    final locationRepo = getIt<UserLocationRepository>();
    MeetingLocation? myHome;
    MeetingLocation? myWork;
    try {
      final (home, work) = await locationRepo.getUserLocations();
      myHome = home;
      myWork = work;
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to read user locations: $e');
    }

    // Read friends' home locations from Firestore in parallel.
    final friendHomeFutures = state.selectedFriendUids.map((uid) async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final data = doc.data();
        if (data == null) return (null, null) as (MeetingLocation?, MeetingLocation?);

        final lat = (data['homeLatitude'] as num?)?.toDouble();
        final lng = (data['homeLongitude'] as num?)?.toDouble();
        final name = data['homeName'] as String? ?? '';

        final home = (lat != null && lng != null)
            ? MeetingLocation(name: name, latitude: lat, longitude: lng)
            : null;
        return (home, null) as (MeetingLocation?, MeetingLocation?);
      } catch (e) {
        if (kDebugMode) debugPrint('Failed to read home for $uid: $e');
        return (null, null) as (MeetingLocation?, MeetingLocation?);
      }
    });

    final friendLocations = await Future.wait(friendHomeFutures);

    return [
      (myHome, myWork),
      ...friendLocations,
    ];
  }

  /// Extracts just the home locations from member location tuples.
  List<MeetingLocation?> _extractHomes(
    List<(MeetingLocation? home, MeetingLocation? work)> memberLocations,
  ) {
    return memberLocations.map((e) => e.$1).toList();
  }

  /// For algorithmic proposals (location == TBD), resolve a real place using
  /// departure-based midpoints + Places API.
  Future<List<MeetingProposal>> _resolveAlgorithmicLocations(
    List<MeetingProposal> proposals,
    List<(MeetingLocation? home, MeetingLocation? work)> memberLocations,
    List<List<Task>> memberSchedules,
  ) async {
    final hasTbd = proposals.any((p) => !p.location.hasCoordinates);
    if (!hasTbd) return proposals;

    final homes = _extractHomes(memberLocations);
    final locationService = getIt<LocationSearchService>();

    // Cache to avoid duplicate API calls for same keyword + similar coords.
    // Key: keyword, Value: (lat, lng, MeetingLocation).
    final cache = <String, (double, double, MeetingLocation)>{};

    final resolved = <MeetingProposal>[];
    for (final proposal in proposals) {
      if (proposal.location.hasCoordinates) {
        resolved.add(proposal);
        continue;
      }

      final targetDate = DateTime(
        proposal.startTime.year,
        proposal.startTime.month,
        proposal.startTime.day,
      );
      final slotStart = TimeOfDay(
        hour: proposal.startTime.hour,
        minute: proposal.startTime.minute,
      );

      final slotEnd = TimeOfDay(
        hour: proposal.endTime.hour,
        minute: proposal.endTime.minute,
      );

      // Compute weighted midpoint based on departure, next destination, and slack.
      final midpoint = _computeWeightedMidpoint(
        memberSchedules, homes, slotStart, slotEnd, targetDate,
      );

      if (midpoint == null) {
        resolved.add(proposal);
        continue;
      }

      final keyword = _keywordForTimeOfDay(proposal.startTime.hour);

      // Reuse cached result if same keyword and midpoint within ~200 m.
      final cached = cache[keyword];
      if (cached != null) {
        final dLat = (cached.$1 - midpoint.$1).abs();
        final dLng = (cached.$2 - midpoint.$2).abs();
        // ~0.002° ≈ 200 m
        if (dLat < 0.002 && dLng < 0.002) {
          resolved.add(proposal.copyWith(location: cached.$3));
          continue;
        }
      }

      try {
        final location = await locationService.findNearestPlace(
          latitude: midpoint.$1,
          longitude: midpoint.$2,
          keyword: keyword,
        );
        cache[keyword] = (midpoint.$1, midpoint.$2, location);
        resolved.add(proposal.copyWith(location: location));
      } catch (e) {
        if (kDebugMode) debugPrint('Place lookup failed: $e');
        resolved.add(proposal);
      }
    }
    return resolved;
  }

  /// Adjusts proposal start/end times based on real travel time.
  ///
  /// For each proposal, finds the latest arrival time across all members
  /// (last task end + driving time) and shifts the meeting start to that
  /// time. Also checks that everyone can leave in time for their next task.
  /// Proposals that don't fit even after adjustment are dropped.
  Future<List<MeetingProposal>> _adjustByTransitTime(
    List<MeetingProposal> proposals,
    List<List<Task>> memberSchedules,
    List<MeetingLocation?> homeLocations,
  ) async {
    if (proposals.isEmpty) return proposals;

    final transitService = getIt<TransitRouteService>();
    final result = <MeetingProposal>[];

    for (final proposal in proposals) {
      if (!proposal.location.hasCoordinates) {
        result.add(proposal);
        continue;
      }

      final targetDate = DateTime(
        proposal.startTime.year,
        proposal.startTime.month,
        proposal.startTime.day,
      );
      final originalStartMin =
          proposal.startTime.hour * 60 + proposal.startTime.minute;
      final duration = proposal.endTime.difference(proposal.startTime);

      // Find the latest arrival time across all members.
      int latestArrivalMin = originalStartMin;

      for (int i = 0; i < memberSchedules.length; i++) {
        final tasks = memberSchedules[i];
        final home = i < homeLocations.length ? homeLocations[i] : null;

        // Find last task ending before or at the slot start.
        MeetingLocation? departure;
        int lastEndMin = -1;
        for (final task in tasks) {
          if (!_taskOccursOnDate(task, targetDate)) continue;
          if (task.endTime == null) continue;
          final endMin = task.endTime!.hour * 60 + task.endTime!.minute;
          if (endMin > originalStartMin) continue;
          if (endMin > lastEndMin) {
            lastEndMin = endMin;
            departure = (task.locationLatitude != null &&
                    task.locationLongitude != null)
                ? MeetingLocation(
                    name: task.locationName ?? '',
                    latitude: task.locationLatitude,
                    longitude: task.locationLongitude,
                  )
                : null;
          }
        }
        departure ??= home;

        if (departure != null &&
            departure.hasCoordinates &&
            lastEndMin >= 0) {
          final travelMin = await transitService.getTransitTimeMinutes(
            origin: departure,
            destination: proposal.location,
          );
          if (travelMin != null) {
            final arrivalMin = lastEndMin + travelMin;
            if (arrivalMin > latestArrivalMin) {
              latestArrivalMin = arrivalMin;
            }
          }
        }
      }

      // Compute the adjusted start/end times.
      final adjustedStart = targetDate.copyWith(
        hour: latestArrivalMin ~/ 60,
        minute: latestArrivalMin % 60,
        second: 0,
        millisecond: 0,
        microsecond: 0,
      );
      final adjustedEnd = adjustedStart.add(duration);

      // Check that everyone can leave in time for their next task.
      final adjustedEndMin = latestArrivalMin + duration.inMinutes;
      bool fits = true;

      for (int i = 0; i < memberSchedules.length; i++) {
        final tasks = memberSchedules[i];
        final home = i < homeLocations.length ? homeLocations[i] : null;

        // Find first task starting after the adjusted meeting end.
        MeetingLocation? nextDest;
        int nextStartMin = 99999;
        for (final task in tasks) {
          if (!_taskOccursOnDate(task, targetDate)) continue;
          if (task.startTime == null) continue;
          final startMin =
              task.startTime!.hour * 60 + task.startTime!.minute;
          if (startMin < adjustedEndMin) continue;
          if (startMin < nextStartMin) {
            nextStartMin = startMin;
            nextDest = (task.locationLatitude != null &&
                    task.locationLongitude != null)
                ? MeetingLocation(
                    name: task.locationName ?? '',
                    latitude: task.locationLatitude,
                    longitude: task.locationLongitude,
                  )
                : null;
          }
        }
        nextDest ??= home;

        if (nextDest != null &&
            nextDest.hasCoordinates &&
            nextStartMin < 99999) {
          final travelMin = await transitService.getTransitTimeMinutes(
            origin: proposal.location,
            destination: nextDest,
          );
          if (travelMin != null &&
              adjustedEndMin + travelMin > nextStartMin) {
            if (kDebugMode) {
              debugPrint(
                '❌ Proposal ${proposal.startTime} dropped: '
                'member $i needs ${travelMin}min to leave, '
                'next task at ${nextStartMin ~/ 60}:'
                '${(nextStartMin % 60).toString().padLeft(2, '0')}',
              );
            }
            fits = false;
            break;
          }
        }
      }

      if (!fits) continue;

      if (latestArrivalMin > originalStartMin && kDebugMode) {
        debugPrint(
          '🕐 Proposal shifted: '
          '${proposal.startTime.hour}:${proposal.startTime.minute.toString().padLeft(2, '0')} → '
          '${adjustedStart.hour}:${adjustedStart.minute.toString().padLeft(2, '0')} '
          '(+${latestArrivalMin - originalStartMin}min travel)',
        );
      }

      result.add(proposal.copyWith(
        startTime: adjustedStart,
        endTime: adjustedEnd,
      ));
    }

    return result;
  }

  /// Computes a weighted GPS midpoint for a meeting slot.
  ///
  /// For each member, calculates:
  /// - **departure**: last task location before the slot, or home
  /// - **next destination**: first task location after the slot, or home
  /// - **personal midpoint**: average of departure and next destination
  /// - **weight**: inversely proportional to slack time after the meeting.
  ///   Less slack → higher weight → midpoint pulled toward that person.
  ///   Free all day → minimal weight → can travel further.
  (double lat, double lng)? _computeWeightedMidpoint(
    List<List<Task>> memberSchedules,
    List<MeetingLocation?> homeLocations,
    TimeOfDay slotStart,
    TimeOfDay slotEnd,
    DateTime targetDate,
  ) {
    final slotStartMin = slotStart.hour * 60 + slotStart.minute;
    final slotEndMin = slotEnd.hour * 60 + slotEnd.minute;

    double sumLat = 0, sumLng = 0, totalWeight = 0;

    for (int i = 0; i < memberSchedules.length; i++) {
      final tasks = memberSchedules[i];
      final home = i < homeLocations.length ? homeLocations[i] : null;

      // ── Departure: last task with location ending before slot ──
      MeetingLocation? departure;
      int lastEndMin = -1;
      for (final task in tasks) {
        if (!_taskOccursOnDate(task, targetDate)) continue;
        if (task.endTime == null) continue;
        final endMin = task.endTime!.hour * 60 + task.endTime!.minute;
        if (endMin > slotStartMin) continue;
        if (task.locationLatitude == null || task.locationLongitude == null) continue;
        if (endMin > lastEndMin) {
          lastEndMin = endMin;
          departure = MeetingLocation(
            name: task.locationName ?? '',
            latitude: task.locationLatitude,
            longitude: task.locationLongitude,
          );
        }
      }
      departure ??= home;

      // ── Next destination: first task with location starting after slot ──
      MeetingLocation? nextDest;
      int nextStartMin = 99999;
      for (final task in tasks) {
        if (!_taskOccursOnDate(task, targetDate)) continue;
        if (task.startTime == null) continue;
        final startMin = task.startTime!.hour * 60 + task.startTime!.minute;
        if (startMin < slotEndMin) continue;
        if (task.locationLatitude == null || task.locationLongitude == null) continue;
        if (startMin < nextStartMin) {
          nextStartMin = startMin;
          nextDest = MeetingLocation(
            name: task.locationName ?? '',
            latitude: task.locationLatitude,
            longitude: task.locationLongitude,
          );
        }
      }
      nextDest ??= home;

      // ── Personal midpoint: average of departure + next destination ──
      final points = [departure, nextDest]
          .where((loc) => loc != null && loc.hasCoordinates)
          .toList();
      if (points.isEmpty) continue;

      final personalLat =
          points.map((p) => p!.latitude!).reduce((a, b) => a + b) / points.length;
      final personalLng =
          points.map((p) => p!.longitude!).reduce((a, b) => a + b) / points.length;

      // ── Weight: based on slack after meeting ──
      // Less slack → higher weight (meeting should be closer to them).
      // No next task → still needs to get home, moderate weight.
      final double slackMinutes;
      if (nextStartMin < 99999) {
        // Has a task after → slack = gap between meeting end and next task start.
        slackMinutes = (nextStartMin - slotEndMin).toDouble();
      } else {
        // No task after → needs to get home but not rushed.
        slackMinutes = 420;
      }
      // weight = 1 / max(slack, 15) — floor of 15 min to avoid extreme weights.
      final weight = 1.0 / slackMinutes.clamp(15, 480);

      sumLat += personalLat * weight;
      sumLng += personalLng * weight;
      totalWeight += weight;
    }

    if (totalWeight == 0) return null;
    return (sumLat / totalWeight, sumLng / totalWeight);
  }

  /// Checks whether a task occurs on a given date.
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

  /// Picks a place category keyword based on the hour of day.
  String _keywordForTimeOfDay(int hour) {
    if (hour < 11) return 'cafe';
    if (hour < 14) return 'restaurant';
    if (hour < 17) return 'cafe';
    if (hour < 20) return 'restaurant';
    return 'bar';
  }

  /// Scores a proposal for ranking. Higher = better.
  ///
  /// Criteria (in priority order):
  /// 1. **Slack** – minimum slack across all members (more slack = better).
  /// 2. **Proximity** – fewer days from [rangeStart] = better.
  /// 3. **Normal hours** – 10:00–22:00 preferred (already filtered, but
  ///    used as a small tiebreaker within that range).
  double _scoreProposal(
    MeetingProposal proposal,
    List<List<Task>> memberSchedules,
    List<MeetingLocation?> homeLocations,
    DateTime rangeStart,
  ) {
    final targetDate = DateTime(
      proposal.startTime.year,
      proposal.startTime.month,
      proposal.startTime.day,
    );
    final slotEndMin =
        proposal.endTime.hour * 60 + proposal.endTime.minute;

    // ── 1. Minimum slack across all members ──
    double minSlack = double.infinity;
    for (int i = 0; i < memberSchedules.length; i++) {
      final tasks = memberSchedules[i];
      int nextStartMin = 99999;
      for (final task in tasks) {
        if (!_taskOccursOnDate(task, targetDate)) continue;
        if (task.startTime == null) continue;
        final startMin = task.startTime!.hour * 60 + task.startTime!.minute;
        if (startMin >= slotEndMin && startMin < nextStartMin) {
          nextStartMin = startMin;
        }
      }
      final slack = nextStartMin < 99999
          ? (nextStartMin - slotEndMin).toDouble()
          : 420.0;
      if (slack < minSlack) minSlack = slack;
    }
    if (minSlack == double.infinity) minSlack = 420.0;

    // ── 2. Days from range start (0 = today) ──
    final daysAway = targetDate.difference(rangeStart).inDays.toDouble();

    // ── 3. Time-of-day preference (peak = 14:00) ──
    final hour = proposal.startTime.hour;
    final hourScore = -(hour - 14).abs().toDouble(); // 0 at 14, -4 at 10 or 18

    // Combine: slack dominates, then proximity, then hour.
    // Slack: 0–480 min → weight 1.0
    // Days: 0–14 → weight ×10 so 1 day ≈ 10 min slack penalty
    // Hour: -8..0 → weight ×2
    return minSlack - (daysAway * 10) + (hourScore * 2);
  }
}

final meetingSuggestionProvider =
    NotifierProvider<MeetingSuggestionNotifier, MeetingSuggestionState>(
  MeetingSuggestionNotifier.new,
);
