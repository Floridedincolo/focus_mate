import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/service_locator.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_completion_status.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/usecases/compute_task_status.dart';
import '../../domain/extensions/task_filter.dart';
import '../providers/task_providers.dart';
import '../models/calendar_icon_data.dart';
import '../widgets/calendar_icon_widget.dart';
import '../widgets/task_item.dart';
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
  late String currentDateText;
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
    currentDateText = "Today";
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

  String getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
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
    String suffix = getDaySuffix(selectedDate.day);
    final tasksAsyncValue = ref.watch(tasksStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text:
                        '${weekdays[selectedDate.weekday - 1]}, ${selectedDate.day}',
                  ),
                  WidgetSpan(
                    child: Transform.translate(
                      offset: const Offset(1, -7),
                      child: Text(
                        suffix,
                        textScaleFactor: 0.7,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  TextSpan(
                    text:
                        ' of ${months[selectedDate.month - 1]} ${selectedDate.year}',
                  ),
                ],
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22.5,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 7.5),
            Text(
              "Your plan for $currentDateText",
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          // Schedule Import button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Tooltip(
                message: 'Import Schedule',
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ScheduleImportPage(),
                    ),
                  ),
                  child: const Icon(
                    Icons.calendar_month_outlined,
                    color: Colors.white70,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          // Profile button
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/profile'),
              child: const CircleAvatar(
                radius: 22,
                backgroundImage: AssetImage('assets/button_bg.png'),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 100,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: calendarIcons.map((e) {
                  bool isSelected =
                      e.dateTime.year == selectedDate.year &&
                      e.dateTime.month == selectedDate.month &&
                      e.dateTime.day == selectedDate.day;
                  return SizedBox(
                    width: MediaQuery.of(context).size.width / 7,
                    child: CalendarIconWidget(
                      calendarIconData: e,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          selectedDate = e.dateTime;
                          currentDateText =
                              (todayDate.day == selectedDate.day &&
                                      todayDate.month == selectedDate.month &&
                                      todayDate.year == selectedDate.year)
                                  ? "Today"
                                  : "This Day";
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
          const SizedBox(height: 14),
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
                  return const Center(
                    child: Text(
                      "No tasks scheduled for this day.",
                      style: TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                  );
                }

                // Cache the future: only re-fetch when tasks or date change
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
                        child:
                            CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    final list = statusSnap.data!;

                    final completedCount = list.where((e) {
                      final task = e['task'] as Task;
                      final key =
                          '${task.id}_${selectedDate.toIso8601String()}';
                      final localStatus = _localCompletions[key];
                      final finalStatus = localStatus ?? e['status'];
                      return finalStatus == TaskCompletionStatus.completed;
                    }).length;
                    final totalCount = list.length;
                    final remainingCount = totalCount - completedCount;

                    list.sort((a, b) {
                      final taskA = a['task'] as Task;
                      final taskB = b['task'] as Task;
                      final keyA =
                          '${taskA.id}_${selectedDate.toIso8601String()}';
                      final keyB =
                          '${taskB.id}_${selectedDate.toIso8601String()}';
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

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _slimStatPill(
                                  "Total",
                                  "$totalCount",
                                  Colors.blueAccent,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _slimStatPill(
                                  "Completed",
                                  "$completedCount",
                                  Colors.green,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _slimStatPill(
                                  "Remaining",
                                  "$remainingCount",
                                  Colors.orange,
                                ),
                              ),
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

                              final key =
                                  '${task.id}_${selectedDate.toIso8601String()}';
                              final localStatus = _localCompletions[key];
                              final status = localStatus ?? firestoreStatus;

                              final localStreak = _localStreaks[task.id];
                              final displayTask = localStreak != null
                                  ? task.copyWith(streak: localStreak)
                                  : task;

                              return TaskItem(
                                task: displayTask,
                                statusForSelectedDay: status,
                                onMarkCompleted: () async {
                                  final isCompleted = status == TaskCompletionStatus.completed;
                                  final newStatus =
                                      isCompleted ? TaskCompletionStatus.upcoming : TaskCompletionStatus.completed;

                                  setState(() {
                                    _localCompletions[key] = newStatus;
                                  });

                                  try {
                                    int updatedStreak;

                                    if (isCompleted) {
                                      updatedStreak = await ref.read(
                                        clearCompletionProvider(
                                          (task, selectedDate),
                                        ).future,
                                      );
                                    } else {
                                      updatedStreak = await ref.read(
                                        markTaskStatusProvider(
                                          (task, selectedDate, newStatus),
                                        ).future,
                                      );
                                    }

                                    setState(() {
                                      _localCompletions[key] = newStatus;
                                      _localStreaks[task.id] = updatedStreak;
                                      // Invalidate cached future so next
                                      // stream emission picks up fresh data
                                      _statusesFuture = null;
                                    });
                                  } catch (e) {
                                    setState(() {
                                      _localCompletions[key] =
                                          firestoreStatus;
                                    });
                                  }
                                },
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
    );
  }

  Widget _slimStatPill(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Compares two task lists by ID to detect if the set of tasks changed.
  bool _taskListsEqual(List<Task>? a, List<Task>? b) {
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }
}

