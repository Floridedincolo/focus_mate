import 'package:flutter/material.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_completion_status.dart';

class TaskItem extends StatelessWidget {
  final Task task;
  final TaskCompletionStatus statusForSelectedDay;
  final VoidCallback? onMarkCompleted;

  /// Called when the user taps the edit button or long-presses the card.
  /// The parent is responsible for navigating to AddTaskMenu with [task].
  final VoidCallback? onEdit;

  const TaskItem({
    super.key,
    required this.task,
    required this.statusForSelectedDay,
    this.onMarkCompleted,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = statusForSelectedDay == TaskCompletionStatus.completed;
    final isMissed = statusForSelectedDay == TaskCompletionStatus.missed;
    final isFutureLocked = onMarkCompleted == null && !isMissed && !isCompleted;

    Color accentColor;
    if (isCompleted) {
      accentColor = Colors.greenAccent;
    } else if (isMissed) {
      accentColor = Colors.redAccent;
    } else if (isFutureLocked) {
      accentColor = Colors.grey;
    } else {
      accentColor = Colors.blueAccent;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: accentColor, width: 3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onLongPress: onEdit,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Completion circle ──
                GestureDetector(
                  onTap: (isMissed || onMarkCompleted == null) ? null : onMarkCompleted,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      isCompleted
                          ? Icons.check_circle_rounded
                          : isMissed
                              ? Icons.cancel_rounded
                              : isFutureLocked
                                  ? Icons.lock_outline
                                  : Icons.radio_button_unchecked_rounded,
                      key: ValueKey(statusForSelectedDay),
                      color: accentColor,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // ── Content ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        task.title,
                        style: TextStyle(
                          color: isCompleted
                              ? Colors.white54
                              : isMissed
                                  ? Colors.redAccent.withValues(alpha: 0.7)
                                  : isFutureLocked
                                      ? Colors.white38
                                      : Colors.white,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 4),

                      // Time + Location row
                      Row(
                        children: [
                          // Time
                          if (task.startTime != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time_rounded,
                                    size: 13, color: Colors.white38),
                                const SizedBox(width: 3),
                                Text(
                                  "${task.startTime!.format(context)}"
                                  "${task.endTime != null ? " – ${task.endTime!.format(context)}" : ""}",
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 12),
                                ),
                              ],
                            ),

                          // Separator
                          if (task.startTime != null &&
                              task.locationName != null &&
                              task.locationName!.isNotEmpty)
                            const Padding(
                              padding:
                                  EdgeInsets.symmetric(horizontal: 6),
                              child: Text('•',
                                  style: TextStyle(
                                      color: Colors.white24,
                                      fontSize: 12)),
                            ),

                          // Location
                          if (task.locationName != null &&
                              task.locationName!.isNotEmpty)
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_rounded,
                                      size: 13,
                                      color: Colors.blueAccent),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      task.locationName!,
                                      style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      // Streak
                      if (task.streak > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                  Icons.local_fire_department_rounded,
                                  color: Colors.orangeAccent,
                                  size: 14),
                              const SizedBox(width: 3),
                              Text(
                                "${task.streak} day${task.streak > 1 ? 's' : ''} streak",
                                style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Edit button ──
                if (onEdit != null)
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined,
                        size: 18, color: Colors.white24),
                    splashRadius: 20,
                    tooltip: 'Edit task',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
