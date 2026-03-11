import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/service_locator.dart';
import '../../domain/entities/meeting_proposal.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/friend_repository.dart';
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

  /// Maximum total proposals to return across all scanned days.
  static const _maxProposals = 5;

  /// Maximum slots to collect per day before filtering (generous to allow
  /// later-hour sorting across the full range).
  static const _maxPerDay = 8;

  Future<void> _runSuggestion() async {
    try {
      // Get current user's tasks from the existing stream.
      final tasksAsync = ref.read(tasksStreamProvider);
      final myTasks = tasksAsync.valueOrNull ?? <Task>[];

      // Fetch each friend's tasks from Firestore
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
          if (kDebugMode) debugPrint('⚠️ Failed to fetch tasks for $friendUid: $e');
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

      // Determine the scan range from state.
      final rangeStart = state.rangeStart ?? DateTime.now();
      final rangeEnd = state.rangeEnd ?? rangeStart.add(const Duration(days: 14));
      final startDate = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
      final endDate = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);
      final totalDays = endDate.difference(startDate).inDays + 1;

      // Scan every day in the range and collect ALL candidate slots.
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
            );
          }

          allCandidates.addAll(dayProposals);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ No slots on ${targetDate.toIso8601String()}: $e');
          }
        }
      }

      // Sort: prefer later hours in the day. For slots with the same start
      // hour, prefer earlier dates so the user gets the soonest options.
      allCandidates.sort((a, b) {
        // Primary: later time-of-day first (descending by hour/minute).
        final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
        final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
        if (aMinutes != bMinutes) return bMinutes.compareTo(aMinutes);
        // Tiebreak: earlier date first (ascending).
        return a.startTime.compareTo(b.startTime);
      });

      // Take the top N.
      final topProposals = allCandidates.take(_maxProposals).toList();

      // Ensure every proposal has the group member UIDs populated so
      // they can be saved to Firestore and queried per-user.
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final allMemberUids = [
        if (currentUid != null) currentUid,
        ...state.selectedFriendUids,
      ];
      final enrichedProposals = topProposals
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
}

/// The global provider for the meeting suggestion wizard.
final meetingSuggestionProvider =
    NotifierProvider<MeetingSuggestionNotifier, MeetingSuggestionState>(
  MeetingSuggestionNotifier.new,
);

