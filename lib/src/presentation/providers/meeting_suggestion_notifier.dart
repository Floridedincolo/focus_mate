import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/service_locator.dart';
import '../../data/datasources/location_search_service.dart';
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

      allCandidates.sort((a, b) {
        final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
        final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
        if (aMinutes != bMinutes) return bMinutes.compareTo(aMinutes);
        return a.startTime.compareTo(b.startTime);
      });

      final topProposals = allCandidates.take(_maxProposals).toList();

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final allMemberUids = [
        if (currentUid != null) currentUid,
        ...state.selectedFriendUids,
      ];

      // ── Resolve locations for algorithmic proposals (TBD → real place) ──
      final resolvedProposals = await _resolveAlgorithmicLocations(
        topProposals,
        memberLocations,
      );

      final enrichedProposals = resolvedProposals
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

  /// Reads the current user's home/work locations. Friends' locations are
  /// unknown (stored in their local SharedPreferences), so we pass null.
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

    return [
      (myHome, myWork),
      // Friends — we don't have access to their stored locations
      for (final _ in state.selectedFriendUids) (null, null),
    ];
  }

  /// For algorithmic proposals (location == TBD), resolve a real place using
  /// the GPS midpoint of all known member locations + Places API.
  Future<List<MeetingProposal>> _resolveAlgorithmicLocations(
    List<MeetingProposal> proposals,
    List<(MeetingLocation? home, MeetingLocation? work)> memberLocations,
  ) async {
    // Only resolve if there are TBD locations
    final hasTbd = proposals.any((p) => !p.location.hasCoordinates);
    if (!hasTbd) return proposals;

    // Compute midpoint from all known coordinates
    final midpoint = _computeMidpoint(memberLocations);
    if (midpoint == null) return proposals; // No coordinates available

    final locationService = getIt<LocationSearchService>();

    final resolved = <MeetingProposal>[];
    for (final proposal in proposals) {
      if (proposal.location.hasCoordinates) {
        resolved.add(proposal);
        continue;
      }

      final keyword = _keywordForTimeOfDay(proposal.startTime.hour);
      try {
        final location = await locationService.findNearestPlace(
          latitude: midpoint.$1,
          longitude: midpoint.$2,
          keyword: keyword,
        );
        resolved.add(proposal.copyWith(location: location));
      } catch (e) {
        if (kDebugMode) debugPrint('Place lookup failed: $e');
        resolved.add(proposal);
      }
    }
    return resolved;
  }

  /// Averages all known coordinates from member locations into a single point.
  (double lat, double lng)? _computeMidpoint(
    List<(MeetingLocation? home, MeetingLocation? work)> memberLocations,
  ) {
    double sumLat = 0, sumLng = 0;
    int count = 0;
    for (final (home, work) in memberLocations) {
      if (home != null && home.hasCoordinates) {
        sumLat += home.latitude!;
        sumLng += home.longitude!;
        count++;
      }
      if (work != null && work.hasCoordinates) {
        sumLat += work.latitude!;
        sumLng += work.longitude!;
        count++;
      }
    }
    if (count == 0) return null;
    return (sumLat / count, sumLng / count);
  }

  /// Picks a place category keyword based on the hour of day.
  String _keywordForTimeOfDay(int hour) {
    if (hour < 11) return 'cafe';
    if (hour < 14) return 'restaurant';
    if (hour < 17) return 'cafe';
    if (hour < 20) return 'restaurant';
    return 'bar';
  }
}

final meetingSuggestionProvider =
    NotifierProvider<MeetingSuggestionNotifier, MeetingSuggestionState>(
  MeetingSuggestionNotifier.new,
);
