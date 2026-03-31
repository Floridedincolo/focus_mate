import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/task.dart';

/// Card that previews a [Task] before it is saved to Firestore.
/// Optionally shows a location row with an edit button.
class TaskPreviewCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onEditLocation;

  const TaskPreviewCard({super.key, required this.task, this.onEditLocation});

  @override
  Widget build(BuildContext context) {
    final hasLocation =
        task.locationName != null && task.locationName!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          task.oneTime ? Icons.event : Icons.repeat,
          color: task.oneTime
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          task.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_subtitle()),
            if (hasLocation || onEditLocation != null)
              GestureDetector(
                onTap: onEditLocation,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: hasLocation
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          hasLocation ? task.locationName! : 'Add location',
                          style: TextStyle(
                            fontSize: 12,
                            color: hasLocation
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white38,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (onEditLocation != null)
                        const Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: Colors.white38,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[];

    // Date / recurrence
    if (task.oneTime) {
      parts.add(DateFormat('EEE, MMM d').format(task.startDate));
    } else {
      final activeDays = task.days.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .join(', ');
      if (activeDays.isNotEmpty) parts.add('Every $activeDays');
    }

    // Time window
    if (task.startTime != null && task.endTime != null) {
      parts.add('${_fmt(task.startTime!)} – ${_fmt(task.endTime!)}');
    }

    return parts.join('  •  ');
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
