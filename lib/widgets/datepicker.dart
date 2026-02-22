import 'package:flutter/material.dart';

class DatePickerField extends StatefulWidget {
  final DateTime? initialDate;
  final void Function(DateTime) onDateSelected;

  const DatePickerField({
    super.key,
    this.initialDate,
    required this.onDateSelected,
  });

  @override
  State<DatePickerField> createState() => _DatePickerFieldState();
}

class _DatePickerFieldState extends State<DatePickerField> {
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate ?? now,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 5),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Colors.cyan,
                  surface: Color(0xFF1A1A1A),
                  onSurface: Colors.white,
                ), dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF0D0D0D)),
              ),
              child: child!,
            );
          },
        );

        if (picked != null) {
          setState(() {
            _selectedDate = picked;
          });
          widget.onDateSelected(picked);
        }
      },
      child: AbsorbPointer(
        //absorb pointer ca copii sa nu primeasca inputu de click
        child: TextField(
          readOnly: true,
          controller: TextEditingController(
            text: _selectedDate != null
                ? "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}"
                : "",
          ),
          decoration: InputDecoration(
            hintText: "Select a date",
            hintStyle: const TextStyle(color: Colors.grey),
            suffixIcon: const Icon(Icons.calendar_today, color: Colors.white70),
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
