import 'package:flutter/material.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_completion_status.dart';
import '../theme/app_colors.dart';

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
      accentColor = AppColors.accentGreen;
    } else if (isMissed) {
      accentColor = AppColors.accentRed;
    } else if (isFutureLocked) {
      accentColor = Colors.grey;
    } else {
      accentColor = AppColors.accentBlue;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Accent bar
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3.5,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
          ),
          // Card content
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onLongPress: onEdit,
              splashColor: accentColor.withValues(alpha: 0.08),
              highlightColor: accentColor.withValues(alpha: 0.04),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Completion circle
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

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              color: isCompleted
                                  ? Colors.white54
                                  : isMissed
                                      ? AppColors.accentRed.withValues(alpha: 0.7)
                                      : isFutureLocked
                                          ? Colors.white38
                                          : Colors.white,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 4),

                          // Time + Location row
                          Row(
                            children: [
                              if (task.startTime != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.access_time_rounded,
                                        size: 13, color: AppColors.textTertiary),
                                    const SizedBox(width: 3),
                                    Text(
                                      "${task.startTime!.format(context)}"
                                      "${task.endTime != null ? " – ${task.endTime!.format(context)}" : ""}",
                                      style: const TextStyle(
                                          color: AppColors.textTertiary, fontSize: 12),
                                    ),
                                  ],
                                ),

                              if (task.startTime != null &&
                                  task.locationName != null &&
                                  task.locationName!.isNotEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Text('\u2022',
                                      style: TextStyle(
                                          color: AppColors.textTertiary,
                                          fontSize: 12)),
                                ),

                              if (task.locationName != null &&
                                  task.locationName!.isNotEmpty)
                                Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.location_on_rounded,
                                          size: 13,
                                          color: AppColors.accentBlue),
                                      const SizedBox(width: 2),
                                      Flexible(
                                        child: Text(
                                          task.locationName!,
                                          style: const TextStyle(
                                              color: AppColors.textTertiary,
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
                                      color: AppColors.accentOrange,
                                      size: 14),
                                  const SizedBox(width: 3),
                                  Text(
                                    "${task.streak} day${task.streak > 1 ? 's' : ''} streak",
                                    style: const TextStyle(
                                      color: AppColors.accentOrange,
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

                    // Edit button
                    if (onEdit != null)
                      IconButton(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined,
                            size: 18, color: AppColors.textTertiary),
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
        ],
      ),
    );
  }
}
