import 'package:flutter/material.dart';
import '../../domain/entities/repeat_type.dart';

class ChooseRepeating extends StatefulWidget {
  final RepeatType repeatType;
  final Function(RepeatType?, Map<String, bool>) onRepeatChanged;
  final Map<String, bool> d;

  const ChooseRepeating({
    super.key,
    required this.onRepeatChanged,
    required this.repeatType,
    required this.d,
  });

  @override
  State<ChooseRepeating> createState() => _ChooseRepeatingState();
}

class _ChooseRepeatingState extends State<ChooseRepeating> {
  late RepeatType _repeatType;
  Map<String, bool> days = {
    'Mon': false,
    'Tue': false,
    'Wed': false,
    'Thu': false,
    'Fri': false,
    'Sat': false,
    'Sun': false,
  };

  @override
  void initState() {
    super.initState();
    _repeatType = widget.repeatType;
    if (widget.repeatType == RepeatType.custom && widget.d.isNotEmpty) {
      days = widget.d;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Repeat type buttons (consistent styling) ──
        Container(
          decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.all(4),
          child: Row(children: [
            _toggleButton(label: 'Daily', selected: _repeatType == RepeatType.daily,
                onTap: () {
                  setState(() {
                    _repeatType = RepeatType.daily;
                    days = {for (final d in days.keys) d: false};
                  });
                  widget.onRepeatChanged(_repeatType, days);
                }),
            _toggleButton(label: 'Weekly', selected: _repeatType == RepeatType.weekly,
                onTap: () {
                  setState(() {
                    _repeatType = RepeatType.weekly;
                    days = {for (final d in days.keys) d: false};
                  });
                  widget.onRepeatChanged(_repeatType, days);
                }),
            _toggleButton(label: 'Custom', selected: _repeatType == RepeatType.custom,
                onTap: () {
                  setState(() => _repeatType = RepeatType.custom);
                  widget.onRepeatChanged(_repeatType, days);
                }),
          ]),
        ),

        // ── Day selector (for Weekly / Custom) ──
        if (_repeatType == RepeatType.custom || _repeatType == RepeatType.weekly) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 10.0,
            runSpacing: 5.0,
            children: days.keys.map((day) {
              return FilterChip(
                label: Text(
                  day.substring(0, 3),
                  style: const TextStyle(color: Colors.white, fontSize: 15.0),
                ),
                selected: days[day]!,
                onSelected: (bool selected) {
                  setState(() {
                    days[day] = selected;
                    widget.onRepeatChanged(_repeatType, days);
                  });
                },
                backgroundColor: const Color(0xFF1A1A1A),
                selectedColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _toggleButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.blueAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: Colors.white,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400, fontSize: 15)),
        ),
      ),
    );
  }
}

