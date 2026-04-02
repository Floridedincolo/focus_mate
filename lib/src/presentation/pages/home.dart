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
import '../theme/app_colors.dart';
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

  void _centerOnSelected({bool animate = false}) {
    int index = calendarIcons.indexWhere(
      (e) =>
          e.dateTime.year == selectedDate.year &&
          e.dateTime.month == selectedDate.month &&
          e.dateTime.day == selectedDate.day,
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

  String _greeting() {
    final hour = TimeOfDay.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
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

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final tasksAsyncValue = ref.watch(tasksStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.bgColor,
        toolbarHeight: 72,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting(),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${weekdays[selectedDate.weekday - 1]}, ${months[selectedDate.month - 1]} ${selectedDate.day}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Tooltip(
            message: 'Friends',
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FriendsPage()),
              ),
              child: const _FriendsBadgeIcon(),
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Import Schedule',
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ScheduleImportPage()),
              ),
              child: const Icon(Icons.calendar_month_outlined,
                  color: AppColors.textSecondary, size: 22),
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/profile'),
              child: const _ProfileAvatar(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Month label
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 6, top: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${months[selectedDate.month - 1]} ${selectedDate.year}',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          // Calendar strip
          SizedBox(
            height: 90,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: calendarIcons.map((e) {
                  bool isSelected = _isSameDay(e.dateTime, selectedDate);
                  bool isToday = _isSameDay(e.dateTime, todayDate);
                  return SizedBox(
                    width: MediaQuery.of(context).size.width / 7,
                    child: CalendarIconWidget(
                      calendarIconData: e,
                      isSelected: isSelected,
                      isToday: isToday,
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
          Expanded(
            child: tasksAsyncValue.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              error: (err, stack) => Center(
                child: Text('Error: $err',
                    style: const TextStyle(color: Colors.white)),
              ),
              data: (allTasks) {
                final tasksForDay = allTasks
                    .where((task) =>
                        task.occursOn(selectedDate) && task.archived == false)
                    .toList();

                if (tasksForDay.isEmpty) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - value)),
                        child: child,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_available_rounded,
                              size: 48,
                              color: AppColors.textTertiary.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text(
                            'No tasks planned',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tap + to add something to your day',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
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
                        child: CircularProgressIndicator(color: Colors.white),
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

                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Column(
                        key: ValueKey(selectedDate),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(child: _slimStatPill("Total", totalCount, AppColors.accentBlue)),
                                const SizedBox(width: 8),
                                Expanded(child: _slimStatPill("Completed", completedCount, AppColors.accentGreen)),
                                const SizedBox(width: 8),
                                Expanded(child: _slimStatPill("Remaining", remainingCount, AppColors.accentOrange)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (context, index) {
                                final entry = list[index];
                                final Task task = entry['task'] as Task;
                                final firestoreStatus =
                                    entry['status'] as TaskCompletionStatus? ?? TaskCompletionStatus.upcoming;

                                final key = '${task.id}_${selectedDate.toIso8601String()}';
                                final localStatus = _localCompletions[key];
                                final status = localStatus ?? firestoreStatus;

                                final localStreak = _localStreaks[task.id];
                                final displayTask = localStreak != null
                                    ? task.copyWith(streak: localStreak)
                                    : task;

                                final warning = ref.watch(transitWarningsProvider)[index];
                                final isFutureDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day)
                                    .isAfter(DateTime(todayDate.year, todayDate.month, todayDate.day));

                                return Column(
                                  children: [
                                    // Transit warning BEFORE this task
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
                                            builder: (_) => AddTaskMenu(existingTask: task),
                                          ),
                                        );
                                      },
                                      onMarkCompleted: isFutureDate ? null : () async {
                                        final isCompleted = status == TaskCompletionStatus.completed;
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
                                              clearCompletionProvider((task, selectedDate)).future,
                                            );
                                          } else {
                                            updatedStreak = await ref.read(
                                              markTaskStatusProvider((task, selectedDate, newStatus)).future,
                                            );
                                          }
                                          setState(() {
                                            _localCompletions[key] = newStatus;
                                            _localStreaks[task.id] = updatedStreak;
                                            _statusesFuture = null;
                                          });
                                        } catch (e) {
                                          setState(() {
                                            _localCompletions[key] = firestoreStatus;
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
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
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
        color: AppColors.accentOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.accentOrange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Travel takes ~$transitMin min, but you only have $availableMin min between tasks",
              style: const TextStyle(color: AppColors.accentOrange, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slimStatPill(String title, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E1E1E), Color(0xFF171717)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: value, end: value),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (context, animValue, _) => Text(
              '$animValue',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
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
        const Icon(Icons.people_outline, color: AppColors.textSecondary, size: 22),
        if (count > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: AppColors.accentRed,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
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
      radius: 18,
      backgroundColor: AppColors.accentBlue.withValues(alpha: 0.2),
      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
      onBackgroundImageError: photoUrl != null ? (_, __) {} : null,
      child: photoUrl == null
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppColors.accentBlue,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            )
          : null,
    );
  }
}
