import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/extracted_class.dart';

/// Card shown for one extracted class (standalone, not typically used in grouped view).
/// The user can toggle homework and adjust the hours per week,
/// mark a final exam, and set an end date that serves both purposes.
class ExtractedClassCard extends StatefulWidget {
  final ExtractedClass extractedClass;
  final ValueChanged<ExtractedClass> onChanged;

  const ExtractedClassCard({
    super.key,
    required this.extractedClass,
    required this.onChanged,
  });

  @override
  State<ExtractedClassCard> createState() => _ExtractedClassCardState();
}

class _ExtractedClassCardState extends State<ExtractedClassCard> {
  void _onChanged(ExtractedClass updated) {
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.extractedClass;
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
              onChanged: (v) => _onChanged(c.copyWith(needsHomework: v)),
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
                          onChanged: (v) => _onChanged(
                            c.copyWith(homeworkHoursPerWeek: v),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),

            const Divider(height: 16),

            // Final exam toggle
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Has final exam?'),
              value: c.hasFinalExam,
              onChanged: (v) {
                DateTime? newEndDate = c.endDate;
                // If enabling exam, preselect 14 weeks from now if not already set
                if (v && newEndDate == null) {
                  newEndDate = DateTime.now().add(const Duration(days: 14 * 7));
                }
                _onChanged(c.copyWith(
                  hasFinalExam: v,
                  endDate: newEndDate,
                ));
              },
            ),

            // End date picker — shows unified end date (exam date if exam, study end date otherwise)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _EndDateRow(
                endDate: c.endDate,
                hasFinalExam: c.hasFinalExam,
                onDateChanged: (newDate) => _onChanged(c.copyWith(endDate: newDate)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Row displaying the end date with a tap-to-pick date interaction.
class _EndDateRow extends StatelessWidget {
  final DateTime? endDate;
  final bool hasFinalExam;
  final ValueChanged<DateTime> onDateChanged;

  const _EndDateRow({
    required this.endDate,
    required this.hasFinalExam,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final displayDate = endDate ?? DateTime.now().add(const Duration(days: 14 * 7));
    final label = hasFinalExam ? 'Exam date' : 'Study ends';

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: ${DateFormat('EEE, MMM d yyyy').format(displayDate)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _pickDate(context, displayDate),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, DateTime initialDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      onDateChanged(picked);
    }
  }
}

