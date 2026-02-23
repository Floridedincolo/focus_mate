import 'package:flutter/material.dart';
import '../../../domain/entities/extracted_class.dart';

/// Card shown in [TimetableAdjustmentPage] for one extracted class.
/// The user can toggle homework and adjust the hours per week.
class ExtractedClassCard extends StatelessWidget {
  final ExtractedClass extractedClass;
  final ValueChanged<ExtractedClass> onChanged;

  const ExtractedClassCard({
    super.key,
    required this.extractedClass,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = extractedClass;
    final startStr = _fmt(c.startTime);
    final endStr = _fmt(c.endTime);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject + day/time row
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.subject,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Chip(
                  label: Text('${c.day}  $startStr–$endStr'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (c.room != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '📍 ${c.room}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),

            const Divider(height: 16),

            // Homework toggle
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Needs weekly study/homework'),
              value: c.needsHomework,
              onChanged: (v) => onChanged(c.copyWith(needsHomework: v)),
            ),

            // Hours slider — only visible when homework is on
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: c.needsHomework
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Study time: ${c.homeworkHoursPerWeek.toStringAsFixed(1)} h/week',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Slider(
                          min: 0.5,
                          max: 8,
                          divisions: 15,
                          value: c.homeworkHoursPerWeek,
                          label: '${c.homeworkHoursPerWeek.toStringAsFixed(1)}h',
                          onChanged: (v) => onChanged(
                            c.copyWith(homeworkHoursPerWeek: v),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

