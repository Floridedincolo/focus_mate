// lib/pages/home.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../models/calendar_icon_data.dart';
import '../widgets/calendar_icon_widget.dart';
import '../widgets/task_item.dart';
import '../services/firestore_service.dart';
import '../extensions/task_filter.dart';
import 'package:focus_mate/firebase_options.dart';
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
  late int _selectedIndex;
  final ScrollController _scrollController = ScrollController();
  late List<CalendarIconData> calendarIcons;

  final firestore = FirestoreService();

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
  final bottomBarColor = const Color(0xFF1A1A1A); // Culoarea barei de jos
  final accentColor = Colors.blueAccent;
  @override
  void initState() {
    super.initState();
    todayDate = DateTime.now();
    selectedDate = todayDate;
    currentDateText = "Today";
    _selectedIndex=0;
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final futures = tasks.map((t) async {
      try {
        // mark hidden to skip tasks not active on selected date before returning them at the end
        if (!t.occursOn(selectedDate)) {
          return {'task': t, 'status': 'hidden'};
        }

        // check stored completion status first
        String status = await firestore.getCompletionStatus(t, selectedDate);

        if (status == 'completed') {
          return {'task': t, 'status': 'completed'};
        }

        // if no status add calculate dynamically
        if (selectedDate.isBefore(today)) {
          status = 'missed';
        } else if (selectedDate.isAfter(today)) {
          status = 'upcoming';
        } else {
          if (t.endTime != null) {
            final taskEnd = DateTime(
              today.year,
              today.month,
              t.endTime!.isBefore(t.startTime!) ? today.day+1:today.day,
              t.endTime!.hour,
              t.endTime!.minute,
            );

            status = now.isBefore(taskEnd) ? 'upcoming' : 'missed';
          } else {
            status = 'upcoming';
          }
        }

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
            child: StreamBuilder<QuerySnapshot>(//live camera
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc('default_user')
                  .collection('tasks')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                final allTasks = snapshot.data!.docs
                    .map((doc) => Task.fromMap(doc.data() as Map<String, dynamic>))
                    .toList();

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
                                      updatedStreak = await firestore.clearCompletion(task, selectedDate);
                                    } else {
                                      updatedStreak = await firestore.markTaskStatus(task, selectedDate, 'completed');
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
        floatingActionButton: FloatingActionButton(
          backgroundColor: accentColor,
          shape: const CircleBorder(),
          elevation: 2,
          onPressed: () => Navigator.pushNamed(context, '/add_task'),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),

        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          color: bottomBarColor,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          clipBehavior: Clip.antiAlias,
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildBottomNavItem(0, Icons.home_outlined, Icons.home, "Home"),
                _buildBottomNavItem(1, Icons.shield_outlined, Icons.shield, "Focus"),
                const SizedBox(width: 48), // Spațiu pentru FAB
                _buildBottomNavItem(2, Icons.bar_chart_outlined, Icons.bar_chart, "Stats"),
                _buildBottomNavItem(3, Icons.person_outline, Icons.person, "Profile"),
              ],
            ),
          ),
        )
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
  Widget _buildBottomNavItem(int index, IconData icon, IconData activeIcon, String label) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });

        // Navigare în funcție de index
        switch (index) {
          case 0: // Home
            Navigator.pushNamed(context, '/home');
            break;
          case 1: // Focus Mode
            Navigator.pushNamed(context, '/focus_page');
            break;
          case 2: // Stats
            // Nu există încă pagina de stats
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Stats page coming soon!'),
                duration: Duration(seconds: 1),
              ),
            );
            break;
          case 3: // Profile
            Navigator.pushNamed(context, '/profile');
            break;
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? Colors.blueAccent : Colors.grey,
              size: 22,
            ),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blueAccent : Colors.grey,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }}