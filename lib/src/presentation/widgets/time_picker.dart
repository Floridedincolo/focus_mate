import 'package:flutter/material.dart';

class TimePicker extends StatefulWidget {
  final TimeOfDay? initialTime;
  final String label;
  final void Function(TimeOfDay) onTimeSelected;

  const TimePicker({
    super.key,
    this.initialTime,
    required this.label,
    required this.onTimeSelected,
  });

  @override
  State<TimePicker> createState() => _TimePickerState();
}

class _TimePickerState extends State<TimePicker> {
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final TimeOfDay now = TimeOfDay.now();
        final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: _selectedTime ?? now,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Colors.cyan,
                  surface: Color(0xFF1A1A1A),
                ),
                dialogTheme: const DialogThemeData(
                  backgroundColor: Color(0xFF0D0D0D),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() => _selectedTime = picked);
          widget.onTimeSelected(picked);
        }
      },
      child: AbsorbPointer(
        child: TextField(
          readOnly: true,
          controller: TextEditingController(
            text: _selectedTime != null ? _selectedTime!.format(context) : "",
          ),
          decoration: InputDecoration(
            hintText: widget.label,
            hintStyle: const TextStyle(color: Colors.white54),
            suffixIcon: const Icon(Icons.alarm, color: Colors.white54),
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

