// lib/pages/home.dart
import 'package:flutter/material.dart';

import '../models/task.dart';
import '../models/calendar_icon_data.dart';
import '../widgets/calendar_icon_widget.dart';
import '../widgets/task_item.dart';
import '../extensions/task_filter.dart';
import 'package:focus_mate/domain/repositories/task_repository.dart';
import 'package:focus_mate/data/repositories/firestore_task_repository.dart';
import 'package:focus_mate/domain/usecases/compute_task_status.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late DateTime selectedDate;
  late DateTime todayDate;
  late DateTime firstDate;
  late DateTime lastDate;
  late String currentDateText;
  final ScrollController _scrollController = ScrollController();
  late List<CalendarIconData> calendarIcons;

  final TaskRepository _taskRepo = FirestoreTaskRepository();

  //  Local cache for instant UI update
  final Map<String, String> _localCompletions = {};

  final List<String> months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final List<String> weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
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

    WidgetsBinding.instance.addPostFrameCallback((_) => _centerOnSelected());//add after widgets initialize to calculate size of the layout
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
        (index * cardWidth) -//how much size to scroll
            (MediaQuery.of(context).size.width / 2) +
            (cardWidth / 2);//to make it to the middle of the screen

    double clamped = target.clamp(
      _scrollController.position.minScrollExtent,//prevent the overscroll
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
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  Future<List<Map<String, dynamic>>> _fetchStatuses(List<Task> tasks) async {
    final futures = tasks.map((t) async {
      try {
        final status = await computeTaskStatus(t, selectedDate, _taskRepo);
        return {'task': t, 'status': status};
      } catch (e) {
        return {'task': t, 'status': 'upcoming'};
      }
    }).toList();

    // remove hidden entries
    return (await Future.wait(futures))
        .where((entry) => entry['status'] != 'hidden')
        .toList();
  }


  @override
  Widget build(BuildContext context) {
    String suffix = getDaySuffix(selectedDate.day);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(//allows multiple text spans and widgets with different styles
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
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                // circular profile picture
                GestureDetector(
                  onTap: () {
                    // Navigate to profile page
                    Navigator.pushNamed(context, '/profile');
                  },
                  child: const CircleAvatar(
                    radius: 22,
                    backgroundImage: AssetImage('assets/button_bg.png'),
                  ),
                ),
              ],
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
            child: StreamBuilder<List<Task>>(
              stream: _taskRepo.watchTasks(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                final allTasks = snapshot.data as List<Task>;

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

                return FutureBuilder<List<Map<String, dynamic>>>(//picture
                  future: _fetchStatuses(tasksForDay),
                  builder: (context, statusSnap) {//status snap is the snpashot of the future hasdata -knows if data loaded or not yet
                    if (!statusSnap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    final list = statusSnap.data!;

                    final completedCount =
                        list.where((e) {
                          final key = '${e['task'].id}_${selectedDate.toIso8601String()}';
                          final  localStatus=_localCompletions[key];
                          final  finalStatus=localStatus??e['status'];
                          return finalStatus == 'completed';
                        }).length;
                    final totalCount = list.length;
                    final remainingCount = totalCount - completedCount;

                    list.sort((a, b) {
                      final taskA=a['task'];
                      final taskB=b['task'];
                      final keyA='${taskA.id}_${selectedDate.toIso8601String()}';
                      final keyB='${taskB.id}_${selectedDate.toIso8601String()}';
                      final localA=_localCompletions[keyA];
                      final localB=_localCompletions[keyB];
                      final statusA=localA??a['status'];
                      final statusB=localB??b['status'];
                      final aDone = statusA == 'completed' ? 1 : 0;
                      final bDone = statusB == 'completed' ? 1 : 0;
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
                                    "Total", "$totalCount", Colors.blueAccent),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _slimStatPill(
                                    "Completed", "$completedCount", Colors.green),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _slimStatPill(
                                    "Remaining", "$remainingCount", Colors.orange),
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
                                  entry['status'] as String? ?? 'upcoming';

                              final key =
                                  '${task.id}_${selectedDate.toIso8601String()}';
                              final localStatus = _localCompletions[key];
                              final status = localStatus ?? firestoreStatus;

                              return TaskItem(
                                task: task,
                                statusForSelectedDay: status,
                                onMarkCompleted: () async {
                                  final isCompleted = status == 'completed';
                                  final newStatus =
                                  isCompleted ? 'upcoming' : 'completed';

                                  setState(() {
                                    _localCompletions[key] = newStatus;
                                  });

                                  try {
                                    int updatedStreak;

                                    if (isCompleted) {
                                      updatedStreak = await _taskRepo.clearCompletion(task, selectedDate);
                                    } else {
                                      updatedStreak = await _taskRepo.markTaskStatus(task, selectedDate, 'completed');
                                    }

                                    setState(() {
                                      _localCompletions[key] = newStatus;
                                      task.streak = updatedStreak;
                                    });

                                  } catch (e) {
                                    // rollback if Firestore fails
                                    setState(() {
                                      _localCompletions[key] = firestoreStatus;
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
          Text(title,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
