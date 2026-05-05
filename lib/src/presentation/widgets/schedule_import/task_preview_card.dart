import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/task.dart';

class TaskPreviewCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onEditLocation;

  const TaskPreviewCard({super.key, required this.task, this.onEditLocation});

  @override
  Widget build(BuildContext context) {
    final hasLocation =
        task.locationName != null && task.locationName!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leading icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: task.oneTime
                  ? Colors.redAccent.withValues(alpha: 0.15)
                  : Colors.blueAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              task.oneTime ? Icons.event : Icons.repeat,
              size: 18,
              color: task.oneTime ? Colors.redAccent : Colors.blueAccent,
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitle(),
                  style: const TextStyle(color: Colors.white30, fontSize: 12),
                ),
                if (hasLocation || onEditLocation != null)
                  GestureDetector(
                    onTap: onEditLocation,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color:
                                hasLocation ? Colors.blueAccent : Colors.white24,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              hasLocation ? task.locationName! : 'Add location',
                              style: TextStyle(
                                fontSize: 12,
                                color: hasLocation
                                    ? Colors.white38
                                    : Colors.white24,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (onEditLocation != null)
                            const Icon(Icons.edit_outlined,
                                size: 13, color: Colors.white24),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[];

    if (task.oneTime) {
      parts.add(DateFormat('EEE, MMM d').format(task.startDate));
    } else {
      final activeDays = task.days.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .join(', ');
      if (activeDays.isNotEmpty) parts.add('Every $activeDays');
    }

    if (task.startTime != null && task.endTime != null) {
      parts.add('${_fmt(task.startTime!)} \u2013 ${_fmt(task.endTime!)}');
    }

    return parts.join('  \u00b7  ');
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
