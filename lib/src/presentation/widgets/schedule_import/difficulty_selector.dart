import 'package:flutter/material.dart';
import '../../../domain/entities/exam_difficulty.dart';

/// A row of Easy / Medium / Hard chip buttons.
class DifficultySelector extends StatelessWidget {
  final ExamDifficulty selected;
  final ValueChanged<ExamDifficulty> onChanged;

  const DifficultySelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: ExamDifficulty.values.map((d) {
        final isSelected = d == selected;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            label: Text(d.label),
            selected: isSelected,
            selectedColor: _chipColor(d),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : null,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            onSelected: (_) => onChanged(d),
          ),
        );
      }).toList(),
    );
  }

  Color _chipColor(ExamDifficulty d) {
    switch (d) {
      case ExamDifficulty.easy:
        return Colors.green;
      case ExamDifficulty.medium:
        return Colors.orange;
      case ExamDifficulty.hard:
        return Colors.red;
    }
  }
}

