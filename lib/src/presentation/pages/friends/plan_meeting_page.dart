import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/meeting_proposal.dart';
import '../../../domain/entities/task.dart';
import '../../models/meeting_suggestion_state.dart';
import '../../providers/friend_providers.dart';
import '../../providers/meeting_suggestion_notifier.dart';
import '../../providers/task_providers.dart';
import '../../widgets/friends/meeting_proposal_card.dart';
import '../../widgets/friends/user_profile_tile.dart';

/// Multi-step wizard for planning a meeting with friends.
///
/// Can be launched with pre-selected friends (from the friends list) or
/// with an empty selection (user picks friends first).
class PlanMeetingPage extends ConsumerStatefulWidget {
  final List<String> preselectedFriendUids;
  final List<String> preselectedFriendNames;

  const PlanMeetingPage({
    super.key,
    this.preselectedFriendUids = const [],
    this.preselectedFriendNames = const [],
  });

  @override
  ConsumerState<PlanMeetingPage> createState() => _PlanMeetingPageState();
}

class _PlanMeetingPageState extends ConsumerState<PlanMeetingPage> {
  @override
  void initState() {
    super.initState();
    // Reset wizard and pre-populate if friends were passed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(meetingSuggestionProvider.notifier);
      notifier.reset();
      if (widget.preselectedFriendUids.isNotEmpty) {
        notifier.selectFriends(
          widget.preselectedFriendUids,
          widget.preselectedFriendNames,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(meetingSuggestionProvider);

    return PopScope(
      canPop: state.step == MeetingSuggestionStep.selectFriends,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(meetingSuggestionProvider.notifier).goBack();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D0D0D),
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            _titleForStep(state.step),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildStep(state),
        ),
      ),
    );
  }

  String _titleForStep(MeetingSuggestionStep step) {
    switch (step) {
      case MeetingSuggestionStep.selectFriends:
        return 'Select Friends';
      case MeetingSuggestionStep.configure:
        return 'Meeting Details';
      case MeetingSuggestionStep.loading:
        return 'Finding Slots…';
      case MeetingSuggestionStep.results:
        return 'Suggestions';
      case MeetingSuggestionStep.error:
        return 'Error';
    }
  }

  Widget _buildStep(MeetingSuggestionState state) {
    switch (state.step) {
      case MeetingSuggestionStep.selectFriends:
        return const _SelectFriendsStep(key: ValueKey('select'));
      case MeetingSuggestionStep.configure:
        return const _ConfigureStep(key: ValueKey('configure'));
      case MeetingSuggestionStep.loading:
        return const _LoadingStep(key: ValueKey('loading'));
      case MeetingSuggestionStep.results:
        return _ResultsStep(
          key: const ValueKey('results'),
          proposals: state.proposals,
        );
      case MeetingSuggestionStep.error:
        return _ErrorStep(
          key: const ValueKey('error'),
          message: state.errorMessage ?? 'Unknown error',
        );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Step 1: Select Friends
// ═══════════════════════════════════════════════════════════════════════════

class _SelectFriendsStep extends ConsumerStatefulWidget {
  const _SelectFriendsStep({super.key});

  @override
  ConsumerState<_SelectFriendsStep> createState() =>
      _SelectFriendsStepState();
}

class _SelectFriendsStepState extends ConsumerState<_SelectFriendsStep> {
  final Set<int> _selectedIndices = {};

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(watchFriendsProvider);

    return friendsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (e, _) => Center(
        child:
            Text('Error: $e', style: const TextStyle(color: Colors.redAccent)),
      ),
      data: (friends) {
        if (friends.isEmpty) {
          return const Center(
            child: Text('Add friends first from the Friends page',
                style: TextStyle(color: Colors.white38)),
          );
        }
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select friends for the meeting:',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: friends.length,
                itemBuilder: (context, i) {
                  final friend = friends[i];
                  final selected = _selectedIndices.contains(i);
                  return UserProfileTile(
                    profile: friend,
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _selectedIndices.remove(i);
                        } else {
                          _selectedIndices.add(i);
                        }
                      });
                    },
                    trailing: Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: selected ? Colors.blueAccent : Colors.white24,
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _selectedIndices.isEmpty
                        ? null
                        : () {
                            final allFriends =
                                ref.read(watchFriendsProvider).valueOrNull ??
                                    [];
                            final uids = _selectedIndices
                                .map((i) => allFriends[i].uid)
                                .toList();
                            final names = _selectedIndices
                                .map((i) => allFriends[i].displayName)
                                .toList();
                            ref
                                .read(meetingSuggestionProvider.notifier)
                                .selectFriends(uids, names);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Continue (${_selectedIndices.length} selected)',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Step 2: Configure (date, duration, method)
// ═══════════════════════════════════════════════════════════════════════════

class _ConfigureStep extends ConsumerStatefulWidget {
  const _ConfigureStep({super.key});

  @override
  ConsumerState<_ConfigureStep> createState() => _ConfigureStepState();
}

class _ConfigureStepState extends ConsumerState<_ConfigureStep> {
  late DateTime _rangeStart;
  late DateTime _rangeEnd;
  int _duration = 60;
  ProposalSource _source = ProposalSource.algorithmic;

  final List<int> _durationOptions = [30, 45, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _rangeStart = DateTime(now.year, now.month, now.day);
    _rangeEnd = _rangeStart.add(const Duration(days: 13));
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _rangeStart : _rangeEnd;
    final first = isStart
        ? DateTime.now()
        : _rangeStart;
    final last = DateTime.now().add(const Duration(days: 90));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: last,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.blueAccent,
            surface: Color(0xFF1A1A1A),
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null) return;
    setState(() {
      if (isStart) {
        _rangeStart = picked;
        // If start is now after end, push end forward.
        if (_rangeStart.isAfter(_rangeEnd)) {
          _rangeEnd = _rangeStart.add(const Duration(days: 7));
        }
      } else {
        _rangeEnd = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(meetingSuggestionProvider);
    final friendNames = state.selectedFriendNames;
    final dayCount = _rangeEnd.difference(_rangeStart).inDays + 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Participants ─────────────────────────────────────────────
          const Text('Participants',
              style: TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              const Chip(
                avatar: Icon(Icons.person, color: Colors.white, size: 16),
                label: Text('You', style: TextStyle(color: Colors.white)),
                backgroundColor: Color(0xFF2A2A2A),
              ),
              ...friendNames.map((n) => Chip(
                    label: Text(n, style: const TextStyle(color: Colors.white)),
                    backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                  )),
            ],
          ),
          const SizedBox(height: 24),

          // ── Date range pickers ───────────────────────────────────────
          const Text('Date Range',
              style: TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _dateButton(label: 'From', date: _rangeStart, onTap: () => _pickDate(isStart: true))),
              const SizedBox(width: 12),
              Expanded(child: _dateButton(label: 'To', date: _rangeEnd, onTap: () => _pickDate(isStart: false))),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Scanning $dayCount day${dayCount == 1 ? '' : 's'} — later hours are prioritised.',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),

          // ── Duration picker ──────────────────────────────────────────
          const Text('Duration',
              style: TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: _durationOptions.map((d) {
              final selected = _duration == d;
              return ChoiceChip(
                label: Text('${d}min'),
                selected: selected,
                selectedColor: Colors.blueAccent,
                backgroundColor: const Color(0xFF1A1A1A),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.white54,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) => setState(() => _duration = d),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── Method toggle ────────────────────────────────────────────
          const Text('Suggestion Method',
              style: TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MethodCard(
                  icon: Icons.calculate,
                  label: 'Algorithm',
                  subtitle: 'Fast, deterministic',
                  selected: _source == ProposalSource.algorithmic,
                  onTap: () =>
                      setState(() => _source = ProposalSource.algorithmic),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MethodCard(
                  icon: Icons.auto_awesome,
                  label: 'AI (Gemini)',
                  subtitle: 'Smart location tips',
                  selected: _source == ProposalSource.ai,
                  onTap: () => setState(() => _source = ProposalSource.ai),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ── Find Slots button ────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                ref.read(meetingSuggestionProvider.notifier).configure(
                      rangeStart: _rangeStart,
                      rangeEnd: _rangeEnd,
                      durationMinutes: _duration,
                      source: _source,
                    );
              },
              icon: const Icon(Icons.search),
              label: const Text('Find Slots',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateButton({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    color: Colors.blueAccent, size: 16),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEE, d MMM').format(date),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? Colors.blueAccent.withValues(alpha: 0.15)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.blueAccent : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? Colors.blueAccent : Colors.white38,
                size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Step 3: Loading
// ═══════════════════════════════════════════════════════════════════════════

class _LoadingStep extends StatelessWidget {
  const _LoadingStep({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.blueAccent),
          SizedBox(height: 20),
          Text('Analysing schedules…',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Step 4: Results
// ═══════════════════════════════════════════════════════════════════════════

class _ResultsStep extends ConsumerStatefulWidget {
  final List<MeetingProposal> proposals;
  const _ResultsStep({super.key, required this.proposals});

  @override
  ConsumerState<_ResultsStep> createState() => _ResultsStepState();
}

class _ResultsStepState extends ConsumerState<_ResultsStep> {
  final Set<int> _savedIndices = {};
  bool _savingAll = false;

  /// Builds a one-time Task from a meeting proposal so it appears in
  /// the user's task list / home screen.
  Task _taskFromProposal(MeetingProposal proposal) {
    final state = ref.read(meetingSuggestionProvider);
    final names = state.selectedFriendNames;
    final who = names.isEmpty ? '' : ' with ${names.join(', ')}';
    final where = proposal.location.name != 'Location TBD'
        ? ' @ ${proposal.location.name}'
        : '';

    return Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Meeting$who$where',
      oneTime: true,
      startDate: proposal.startTime,
      startTime: TimeOfDay.fromDateTime(proposal.startTime),
      endTime: TimeOfDay.fromDateTime(proposal.endTime),
      locationName: proposal.location.name != 'Location TBD'
          ? proposal.location.name
          : null,
      locationLatitude: proposal.location.latitude,
      locationLongitude: proposal.location.longitude,
    );
  }

  Future<void> _saveProposal(MeetingProposal proposal, int index) async {
    try {
      final repo = ref.read(friendRepositoryProvider);
      await repo.saveMeetingProposal(proposal);

      // Also create a task so it shows on the home screen.
      await ref.read(saveTaskProvider(_taskFromProposal(proposal)).future);

      if (mounted) {
        setState(() => _savedIndices.add(index));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meeting saved & added to your tasks!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _saveAll() async {
    setState(() => _savingAll = true);
    final repo = ref.read(friendRepositoryProvider);
    for (var i = 0; i < widget.proposals.length; i++) {
      if (_savedIndices.contains(i)) continue;
      try {
        await repo.saveMeetingProposal(widget.proposals[i]);
        await ref.read(
            saveTaskProvider(_taskFromProposal(widget.proposals[i])).future);
        if (mounted) setState(() => _savedIndices.add(i));
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _savingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All meetings saved & added to your tasks!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.proposals.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy, color: Colors.white24, size: 64),
              SizedBox(height: 16),
              Text('No available slots found',
                  style: TextStyle(color: Colors.white38, fontSize: 16)),
              SizedBox(height: 8),
              Text('Try a different date or shorter duration',
                  style: TextStyle(color: Colors.white24, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: widget.proposals.length,
            itemBuilder: (context, i) {
              final saved = _savedIndices.contains(i);
              return Stack(
                children: [
                  MeetingProposalCard(
                      proposal: widget.proposals[i], index: i),
                  Positioned(
                    right: 24,
                    bottom: 14,
                    child: saved
                        ? const Chip(
                            avatar: Icon(Icons.check,
                                color: Colors.white, size: 16),
                            label: Text('Saved',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12)),
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          )
                        : TextButton.icon(
                            onPressed: () =>
                                _saveProposal(widget.proposals[i], i),
                            icon: const Icon(Icons.save,
                                size: 16, color: Colors.blueAccent),
                            label: const Text('Save',
                                style: TextStyle(
                                    color: Colors.blueAccent, fontSize: 12)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              backgroundColor:
                                  Colors.blueAccent.withValues(alpha: 0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _savingAll ||
                        _savedIndices.length == widget.proposals.length
                    ? null
                    : _saveAll,
                icon: _savingAll
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_alt),
                label: Text(
                  _savedIndices.length == widget.proposals.length
                      ? 'All Saved ✓'
                      : 'Save All Suggestions',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Step 5: Error
// ═══════════════════════════════════════════════════════════════════════════

class _ErrorStep extends ConsumerWidget {
  final String message;
  const _ErrorStep({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () =>
                  ref.read(meetingSuggestionProvider.notifier).goBack(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

