import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/service_locator.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_completion_status.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/usecases/compute_task_status.dart';
import '../../domain/extensions/task_filter.dart';
import '../providers/task_providers.dart';
import '../providers/transit_warning_providers.dart';
import '../providers/friend_providers.dart';
import '../models/calendar_icon_data.dart';
import '../widgets/calendar_icon_widget.dart';
import '../widgets/task_item.dart';
import 'add_task.dart';
import 'friends/friends_page.dart';
import 'schedule_import/schedule_import_page.dart';

class Home extends ConsumerStatefulWidget {
  const Home({super.key});

  @override
  ConsumerState<Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<Home> {
  late DateTime selectedDate;
  late DateTime todayDate;
  late DateTime firstDate;
  late DateTime lastDate;
  final ScrollController _scrollController = ScrollController();
  late List<CalendarIconData> calendarIcons;

  final Map<String, TaskCompletionStatus> _localCompletions = {};
  final Map<String, int> _localStreaks = {};

  Future<List<Map<String, dynamic>>>? _statusesFuture;
  List<Task>? _lastTasksForDay;
  DateTime? _lastSelectedDate;

  final List<String> months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  final List<String> weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    todayDate = DateTime.now();
    selectedDate = todayDate;
    int totalDays = 203;
    firstDate = todayDate.subtract(Duration(days: totalDays ~/ 2));
    lastDate = todayDate.add(Duration(days: totalDays ~/ 2));

    DateTime currentDate = firstDate;
    calendarIcons = [];
    for (int i = 0; i < totalDays; i++) {
      calendarIcons.add(CalendarIconData(currentDate));
      currentDate = currentDate.add(const Duration(days: 1));
    }

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _centerOnSelected(),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _isToday => _isSameDay(selectedDate, todayDate);

  String get _headerTitle {
    if (_isToday) return 'Today';
    if (_isSameDay(selectedDate, todayDate.add(const Duration(days: 1)))) {
      return 'Tomorrow';
    }
    if (_isSameDay(selectedDate, todayDate.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return weekdays[selectedDate.weekday - 1];
  }

  String get _headerSubtitle {
    return '${months[selectedDate.month - 1]} ${selectedDate.day}, ${selectedDate.year}';
  }

  void _centerOnSelected({bool animate = false}) {
    int index = calendarIcons.indexWhere(
      (e) => _isSameDay(e.dateTime, selectedDate),
    );

    if (index == -1) return;

    double cardWidth = MediaQuery.of(context).size.width / 7;
    double target =
        (index * cardWidth) -
        (MediaQuery.of(context).size.width / 2) +
        (cardWidth / 2);

    double clamped = target.clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );

    if (animate) {
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _scrollController.jumpTo(clamped);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchStatuses(List<Task> tasks) async {
    final repo = getIt<TaskRepository>();
    final futures = tasks.map((t) async {
      try {
        final status = await computeTaskStatus(t, selectedDate, repo);
        return {'task': t, 'status': status};
      } catch (e) {
        return {'task': t, 'status': TaskCompletionStatus.upcoming};
      }
    }).toList();

    return (await Future.wait(futures))
        .where((entry) => entry['status'] != TaskCompletionStatus.hidden)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsyncValue = ref.watch(tasksStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _headerTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _headerSubtitle,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Action icons
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FriendsPage()),
                    ),
                    child: const _FriendsBadgeIcon(),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ScheduleImportPage()),
                    ),
                    child: const Icon(Icons.calendar_month_outlined,
                        color: Colors.white38, size: 22),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/profile'),
                    child: const _ProfileAvatar(),
                  ),
                ],
              ),
            ),

            // ── Calendar ──
            SizedBox(
              height: 100,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: calendarIcons.map((e) {
                    bool isSelected = _isSameDay(e.dateTime, selectedDate);
                    bool isDayToday = _isSameDay(e.dateTime, todayDate);
                    return SizedBox(
                      width: MediaQuery.of(context).size.width / 7,
                      child: CalendarIconWidget(
                        calendarIconData: e,
                        isSelected: isSelected,
                        isToday: isDayToday,
                        onTap: () {
                          setState(() {
                            selectedDate = e.dateTime;
                            ref.read(transitWarningsProvider.notifier).reset();
                          });
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _centerOnSelected(animate: true),
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Content ──
            Expanded(
              child: tasksAsyncValue.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white24),
                ),
                error: (err, stack) => Center(
                  child: Text('Error: $err',
                      style: const TextStyle(color: Colors.white38)),
                ),
                data: (allTasks) {
                  final tasksForDay = allTasks
                      .where((task) =>
                          task.occursOn(selectedDate) && task.archived == false)
                      .toList();

                  if (tasksForDay.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_available_outlined,
                              size: 48, color: Colors.white.withValues(alpha: 0.08)),
                          const SizedBox(height: 12),
                          const Text(
                            'No tasks for this day',
                            style: TextStyle(color: Colors.white30, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }

                  if (_statusesFuture == null ||
                      _lastSelectedDate != selectedDate ||
                      !_taskListsEqual(_lastTasksForDay, tasksForDay)) {
                    _lastTasksForDay = tasksForDay;
                    _lastSelectedDate = selectedDate;
                    _statusesFuture = _fetchStatuses(tasksForDay);
                  }

                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: _statusesFuture,
                    builder: (context, statusSnap) {
                      if (!statusSnap.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white24),
                        );
                      }

                      final list = statusSnap.data!;

                      final completedCount = list.where((e) {
                        final task = e['task'] as Task;
                        final key = '${task.id}_${selectedDate.toIso8601String()}';
                        final localStatus = _localCompletions[key];
                        final finalStatus = localStatus ?? e['status'];
                        return finalStatus == TaskCompletionStatus.completed;
                      }).length;
                      final totalCount = list.length;
                      final remainingCount = totalCount - completedCount;

                      list.sort((a, b) {
                        final taskA = a['task'] as Task;
                        final taskB = b['task'] as Task;
                        final keyA = '${taskA.id}_${selectedDate.toIso8601String()}';
                        final keyB = '${taskB.id}_${selectedDate.toIso8601String()}';
                        final localA = _localCompletions[keyA];
                        final localB = _localCompletions[keyB];
                        final statusA = localA ?? a['status'];
                        final statusB = localB ?? b['status'];
                        final aDone = statusA == TaskCompletionStatus.completed ? 1 : 0;
                        final bDone = statusB == TaskCompletionStatus.completed ? 1 : 0;
                        if (aDone != bDone) return aDone - bDone;
                        final at = taskA.startTime;
                        final bt = taskB.startTime;
                        if (at == null && bt == null) return 0;
                        if (at == null) return 1;
                        if (bt == null) return -1;
                        return (at.hour * 60 + at.minute)
                            .compareTo(bt.hour * 60 + bt.minute);
                      });

                      // Trigger transit warning computation via provider
                      final sortedTasks = list.map((e) => e['task'] as Task).toList();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          ref.read(transitWarningsProvider.notifier).compute(sortedTasks);
                        }
                      });

                      return Column(
                        children: [
                          // ── Stats card ──
                          _buildStatsCard(totalCount, completedCount, remainingCount),

                          const SizedBox(height: 12),

                          // ── Task list ──
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.only(top: 4, bottom: 80),
                              itemCount: list.length,
                              itemBuilder: (context, index) {
                                final entry = list[index];
                                final Task task = entry['task'] as Task;
                                final firestoreStatus =
                                    entry['status'] as TaskCompletionStatus? ??
                                        TaskCompletionStatus.upcoming;

                                final key = '${task.id}_${selectedDate.toIso8601String()}';
                                final localStatus = _localCompletions[key];
                                final status = localStatus ?? firestoreStatus;

                                final localStreak = _localStreaks[task.id];
                                final displayTask = localStreak != null
                                    ? task.copyWith(streak: localStreak)
                                    : task;

                                final warning = ref.watch(transitWarningsProvider)[index];
                                final isFutureDate = DateTime(selectedDate.year,
                                        selectedDate.month, selectedDate.day)
                                    .isAfter(DateTime(todayDate.year,
                                        todayDate.month, todayDate.day));

                                return Column(
                                  children: [
                                    if (warning != null)
                                      _buildTransitWarningWidget(
                                        transitMin: warning.transitMin,
                                        availableMin: warning.availableMin,
                                      ),
                                    TaskItem(
                                      task: displayTask,
                                      statusForSelectedDay: status,
                                      onEdit: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                AddTaskMenu(existingTask: task),
                                          ),
                                        );
                                      },
                                      onMarkCompleted: isFutureDate
                                          ? null
                                          : () async {
                                              final isCompleted = status ==
                                                  TaskCompletionStatus.completed;
                                              final newStatus = isCompleted
                                                  ? TaskCompletionStatus.upcoming
                                                  : TaskCompletionStatus.completed;

                                              setState(() {
                                                _localCompletions[key] = newStatus;
                                              });

                                              try {
                                                int updatedStreak;
                                                if (isCompleted) {
                                                  updatedStreak = await ref.read(
                                                    clearCompletionProvider(
                                                            (task, selectedDate))
                                                        .future,
                                                  );
                                                } else {
                                                  updatedStreak = await ref.read(
                                                    markTaskStatusProvider((task,
                                                            selectedDate, newStatus))
                                                        .future,
                                                  );
                                                }
                                                setState(() {
                                                  _localCompletions[key] = newStatus;
                                                  _localStreaks[task.id] =
                                                      updatedStreak;
                                                  _statusesFuture = null;
                                                });
                                              } catch (e) {
                                                setState(() {
                                                  _localCompletions[key] =
                                                      firestoreStatus;
                                                });
                                              }
                                            },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(int total, int completed, int remaining) {
    final progress = total > 0 ? completed / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 0),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Stat values row
            Row(
              children: [
                Expanded(
                  child: _statColumn('$total', 'Total', Colors.white),
                ),
                Container(width: 1, height: 28, color: Colors.white10),
                Expanded(
                  child: _statColumn('$completed', 'Done', Colors.greenAccent),
                ),
                Container(width: 1, height: 28, color: Colors.white10),
                Expanded(
                  child: _statColumn('$remaining', 'Left', Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Progress bar
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.04),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statColumn(String value, String label, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildTransitWarningWidget({
    required int transitMin,
    required int availableMin,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Travel takes ~$transitMin min, but you only have $availableMin min between tasks",
              style: const TextStyle(
                  color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  bool _taskListsEqual(List<Task>? a, List<Task>? b) {
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// People icon with a red badge dot when there are pending incoming requests.
class _FriendsBadgeIcon extends ConsumerWidget {
  const _FriendsBadgeIcon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomingAsync = ref.watch(watchIncomingRequestsProvider);
    final count = incomingAsync.valueOrNull?.length ?? 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.people_outline, color: Colors.white38, size: 22),
        if (count > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Small avatar showing the current user's photo or initials.
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;
    final name = user?.displayName ?? '';

    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.blueAccent.withValues(alpha: 0.15),
      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
      onBackgroundImageError: photoUrl != null ? (_, __) {} : null,
      child: photoUrl == null
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            )
          : null,
    );
  }
}
