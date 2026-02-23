import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/extracted_exam.dart';
import 'difficulty_selector.dart';

/// Card shown in [ExamAdjustmentPage] for one extracted exam.
/// The user sets the [ExamDifficulty] here.
class ExtractedExamCard extends StatelessWidget {
  final ExtractedExam exam;
  final ValueChanged<ExtractedExam> onChanged;

  const ExtractedExamCard({
    super.key,
    required this.exam,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM d yyyy').format(exam.date);
    final startStr = _fmt(exam.startTime);
    final endStr = _fmt(exam.endTime);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exam.subject,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text('📅 $dateStr  •  $startStr–$endStr'),
            if (exam.location != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '📍 ${exam.location}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Difficulty:',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            DifficultySelector(
              selected: exam.difficulty,
              onChanged: (d) => onChanged(exam.copyWith(difficulty: d)),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

