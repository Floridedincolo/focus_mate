import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/extracted_class.dart';
import 'edit_class_dialog.dart';

/// Card shown in [TimetableAdjustmentPage] for one **subject** (grouped).
///
/// Displays all day/time occurrences as chips, plus a single homework
/// toggle and a single hours-per-week slider that apply to the subject
/// as a whole. Also includes a "Has final exam?" toggle with a unified end date picker.
/// Each occurrence chip has an edit icon so the user can correct AI
/// extraction mistakes.
class SubjectGroupCard extends StatelessWidget {
  /// All [ExtractedClass] occurrences that share the same subject name.
  final List<ExtractedClass> occurrences;

  /// Called when the user changes any setting (homework, exam, etc.).
  final void Function({
    required bool needsHomework,
    required double homeworkHoursPerWeek,
    required bool hasFinalExam,
    required DateTime? endDate,
  }) onChanged;

  /// Called when the user edits a single occurrence via the edit dialog.
  /// The caller receives the original [ExtractedClass] and the updated one.
  final void Function(ExtractedClass original, ExtractedClass updated)? onOccurrenceEdited;

  const SubjectGroupCard({
    super.key,
    required this.occurrences,
    required this.onChanged,
    this.onOccurrenceEdited,
  });

  @override
  Widget build(BuildContext context) {
    assert(occurrences.isNotEmpty);
    final representative = occurrences.first;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject name
            Text(
              representative.subject,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),

            const SizedBox(height: 8),

            // Day/time chips for every occurrence — tappable to edit
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: occurrences.map((c) {
                final start = _fmt(c.startTime);
                final end = _fmt(c.endTime);
                final roomSuffix = c.room != null ? '  📍${c.room}' : '';
                return ActionChip(
                  avatar: const Icon(Icons.edit_outlined, size: 16),
                  label: Text('${c.day}  $start–$end$roomSuffix'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _editOccurrence(context, c),
                );
              }).toList(),
            ),

            const Divider(height: 16),

            // Homework toggle
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Needs weekly study/homework'),
              value: representative.needsHomework,
              onChanged: (v) => onChanged(
                needsHomework: v,
                homeworkHoursPerWeek: representative.homeworkHoursPerWeek,
                hasFinalExam: representative.hasFinalExam,
                endDate: representative.endDate,
              ),
            ),

            // Hours slider — only visible when homework is on
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: representative.needsHomework
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Study time: ${representative.homeworkHoursPerWeek.toStringAsFixed(1)} h/week',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Slider(
                          min: 0.5,
                          max: 8,
                          divisions: 15,
                          value: representative.homeworkHoursPerWeek,
                          label:
                              '${representative.homeworkHoursPerWeek.toStringAsFixed(1)}h',
                          onChanged: (v) => onChanged(
                            needsHomework: representative.needsHomework,
                            homeworkHoursPerWeek: v,
                            hasFinalExam: representative.hasFinalExam,
                            endDate: representative.endDate,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),

            const Divider(height: 16),

            // ── Has final exam toggle ──
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Has final exam?'),
              value: representative.hasFinalExam,
              onChanged: (v) {
                DateTime? newEndDate = representative.endDate;
                // If enabling exam, preselect 14 weeks from now if not already set
                if (v && newEndDate == null) {
                  newEndDate = DateTime.now().add(const Duration(days: 14 * 7));
                }
                onChanged(
                  needsHomework: representative.needsHomework,
                  homeworkHoursPerWeek: representative.homeworkHoursPerWeek,
                  hasFinalExam: v,
                  endDate: newEndDate,
                );
              },
            ),

            // End date picker — shows for all cases
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _EndDateRow(
                endDate: representative.endDate,
                hasFinalExam: representative.hasFinalExam,
                onDateChanged: (newDate) => onChanged(
                  needsHomework: representative.needsHomework,
                  homeworkHoursPerWeek: representative.homeworkHoursPerWeek,
                  hasFinalExam: representative.hasFinalExam,
                  endDate: newDate,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editOccurrence(BuildContext context, ExtractedClass original) async {
    final updated = await EditClassDialog.show(context, original);
    if (updated != null && onOccurrenceEdited != null) {
      onOccurrenceEdited!(original, updated);
    }
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Row displaying the end date with a tap-to-pick date interaction.
/// Shows as "Exam: ..." if hasFinalExam is true, otherwise "Study ends: ..."
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
          Text(
            '$label: ${DateFormat('EEE, MMM d yyyy').format(displayDate)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
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

