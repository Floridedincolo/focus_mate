import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/extracted_class.dart';
import 'edit_class_dialog.dart';

class SubjectGroupCard extends StatelessWidget {
  final List<ExtractedClass> occurrences;

  final void Function({
    required bool needsHomework,
    required double homeworkHoursPerWeek,
    required bool hasFinalExam,
    required DateTime? endDate,
  }) onChanged;

  final void Function(ExtractedClass original, ExtractedClass updated)?
      onOccurrenceEdited;

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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject name
          Text(
            representative.subject,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),

          // Day/time chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: occurrences.map((c) {
              final start = _fmt(c.startTime);
              final end = _fmt(c.endTime);
              final roomSuffix = c.room != null ? '  \u{1F4CD}${c.room}' : '';
              return GestureDetector(
                onTap: () => _editOccurrence(context, c),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_outlined,
                          size: 13, color: Colors.white24),
                      const SizedBox(width: 6),
                      Text(
                        '${c.day}  $start\u2013$end$roomSuffix',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
                height: 1, color: Colors.white.withValues(alpha: 0.06)),
          ),

          // Homework toggle
          _switchRow(
            title: 'Needs weekly study/homework',
            value: representative.needsHomework,
            onChanged: (v) => onChanged(
              needsHomework: v,
              homeworkHoursPerWeek: representative.homeworkHoursPerWeek,
              hasFinalExam: representative.hasFinalExam,
              endDate: representative.endDate,
            ),
          ),

          // Hours slider
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: representative.needsHomework
                ? Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Study time: ${representative.homeworkHoursPerWeek.toStringAsFixed(1)} h/week',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 13),
                        ),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: Colors.blueAccent,
                            inactiveTrackColor:
                                Colors.blueAccent.withValues(alpha: 0.2),
                            thumbColor: Colors.white,
                            overlayColor:
                                Colors.blueAccent.withValues(alpha: 0.1),
                            trackHeight: 3,
                          ),
                          child: Slider(
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
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Container(
                height: 1, color: Colors.white.withValues(alpha: 0.06)),
          ),

          // Final exam toggle
          _switchRow(
            title: 'Has final exam?',
            value: representative.hasFinalExam,
            onChanged: (v) {
              DateTime? newEndDate = representative.endDate;
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

          // End date
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
    );
  }

  Widget _switchRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ),
          SizedBox(
            height: 28,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.blueAccent,
              inactiveTrackColor: Colors.white12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editOccurrence(
      BuildContext context, ExtractedClass original) async {
    final updated = await EditClassDialog.show(context, original);
    if (updated != null && onOccurrenceEdited != null) {
      onOccurrenceEdited!(original, updated);
    }
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

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
    final displayDate =
        endDate ?? DateTime.now().add(const Duration(days: 14 * 7));
    final label = hasFinalExam ? 'Exam date' : 'Study ends';

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined,
              size: 15, color: Colors.white30),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: ${DateFormat('EEE, MMM d yyyy').format(displayDate)}',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () => _pickDate(context, displayDate),
            child: const Text('Change',
                style: TextStyle(color: Colors.blueAccent, fontSize: 13)),
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
