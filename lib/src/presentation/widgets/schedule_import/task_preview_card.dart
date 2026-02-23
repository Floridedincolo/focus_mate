import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/task.dart';

/// Read-only card that previews a [Task] before it is saved to Firestore.
class TaskPreviewCard extends StatelessWidget {
  final Task task;

  const TaskPreviewCard({super.key, required this.task});

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
        subtitle: Text(_subtitle()),
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

