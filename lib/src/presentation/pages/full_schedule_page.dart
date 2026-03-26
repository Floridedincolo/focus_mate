import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/task.dart';
import '../../domain/usecases/task_occurrence.dart';
import '../providers/task_providers.dart';

class FullSchedulePage extends ConsumerWidget {
  const FullSchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksStreamProvider);
    final today = DateTime.now();
    final days = List.generate(7, (i) => today.add(Duration(days: i)));

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text('Full Schedule',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.redAccent))),
        data: (allTasks) {
          final activeTasks = allTasks.where((t) => !t.archived).toList();

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 32),
            itemCount: days.length,
            itemBuilder: (context, dayIndex) {
              final date = days[dayIndex];
              final tasksForDay = activeTasks.where((t) => occursOnTask(t, date)).toList();

              tasksForDay.sort((a, b) {
                if (a.startTime == null && b.startTime == null) return 0;
                if (a.startTime == null) return 1;
                if (b.startTime == null) return -1;
                return (a.startTime!.hour * 60 + a.startTime!.minute)
                    .compareTo(b.startTime!.hour * 60 + b.startTime!.minute);
              });

              final isToday = dayIndex == 0;
              final dateLabel = isToday
                  ? 'Today — ${DateFormat('EEEE, MMM d').format(date)}'
                  : DateFormat('EEEE, MMM d').format(date);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      dateLabel,
                      style: TextStyle(
                        color: isToday ? Colors.blueAccent : Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (tasksForDay.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('No tasks',
                          style: TextStyle(color: Colors.white30, fontSize: 13)),
                    ),
                  ...tasksForDay.map((task) => _ScheduleTaskTile(task: task)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ScheduleTaskTile extends StatelessWidget {
  final Task task;
  const _ScheduleTaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: Colors.blueAccent, width: 3)),
      ),
      child: Row(
        children: [
          if (task.startTime != null)
            SizedBox(
              width: 60,
              child: Text(
                task.startTime!.format(context),
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                if (task.endTime != null && task.startTime != null)
                  Text(
                    '${task.startTime!.format(context)} – ${task.endTime!.format(context)}',
                    style: const TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                if (task.locationName != null && task.locationName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 12, color: Colors.blueAccent),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(task.locationName!,
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
