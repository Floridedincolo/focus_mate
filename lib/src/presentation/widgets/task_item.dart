import 'package:flutter/material.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_completion_status.dart';

class TaskItem extends StatelessWidget {
  final Task task;
  final TaskCompletionStatus statusForSelectedDay;
  final VoidCallback onMarkCompleted;

  const TaskItem({
    super.key,
    required this.task,
    required this.statusForSelectedDay,
    required this.onMarkCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = statusForSelectedDay == TaskCompletionStatus.completed;
    final isMissed = statusForSelectedDay == TaskCompletionStatus.missed;

    Color statusColor;
    if (isCompleted) {
      statusColor = Colors.greenAccent;
    } else if (isMissed) {
      statusColor = Colors.redAccent;
    } else {
      statusColor = Colors.orangeAccent;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMissed ? Colors.redAccent.withOpacity(0.5) : Colors.white12,
          width: 1.2,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: GestureDetector(
          onTap: (isMissed) ? null : onMarkCompleted,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              isCompleted
                  ? Icons.check_circle
                  : isMissed
                      ? Icons.cancel
                      : Icons.circle_outlined,
              key: ValueKey(statusForSelectedDay),
              color: statusColor,
              size: 28,
            ),
          ),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            color: isCompleted
                ? Colors.greenAccent
                : isMissed
                    ? Colors.redAccent.withOpacity(0.8)
                    : Colors.white,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.startTime != null)
              Text(
                "${task.startTime!.format(context)}"
                "${task.endTime != null ? " - ${task.endTime!.format(context)}" : ""}",
                style: const TextStyle(color: Colors.white54),
              ),
            if (task.streak > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: Colors.orangeAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${task.streak} day${task.streak > 1 ? 's' : ''} streak",
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

