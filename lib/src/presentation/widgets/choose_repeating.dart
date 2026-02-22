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
    'Monday': false,
    'Tuesday': false,
    'Wednesday': false,
    'Thursday': false,
    'Friday': false,
    'Saturday': false,
    'Sunday': false,
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
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: const Color(0xFF1A1A1A),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() => _repeatType = RepeatType.daily);
                  widget.onRepeatChanged(_repeatType, days);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _repeatType == RepeatType.daily
                        ? Colors.blueAccent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Daily',
                    style: TextStyle(color: Colors.white, fontSize: 20.0),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _repeatType = RepeatType.weekly);
                  widget.onRepeatChanged(_repeatType, days);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _repeatType == RepeatType.weekly
                        ? Colors.blueAccent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Weekly',
                    style: TextStyle(color: Colors.white, fontSize: 20.0),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _repeatType = RepeatType.custom);
                  widget.onRepeatChanged(_repeatType, days);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _repeatType == RepeatType.custom
                        ? Colors.blueAccent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Custom',
                    style: TextStyle(color: Colors.white, fontSize: 20.0),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_repeatType == RepeatType.custom) ...[
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
}

