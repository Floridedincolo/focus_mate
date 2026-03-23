import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/task.dart';

/// Read-only card that previews a [Task] before it is saved to Firestore.
///
/// Displays the location (if set) and offers an edit-location callback.
class TaskPreviewCard extends StatelessWidget {
  final Task task;

  /// Called when the user taps the location edit icon. The parent is
  /// responsible for showing a dialog / autocomplete and calling
  /// `notifier.updatePreviewTaskLocation(index, newName)`.
  final VoidCallback? onEditLocation;

  const TaskPreviewCard({
    super.key,
    required this.task,
    this.onEditLocation,
  });

  @override
  Widget build(BuildContext context) {
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
            if (task.locationName != null && task.locationName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 14, color: Colors.blueAccent),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        task.locationName!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: onEditLocation != null
            ? IconButton(
                icon: const Icon(Icons.edit_location_alt_outlined, size: 20),
                tooltip: 'Change location',
                onPressed: onEditLocation,
              )
            : null,
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

