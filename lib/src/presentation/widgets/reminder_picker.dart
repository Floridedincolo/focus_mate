import 'package:flutter/material.dart';
import '../../domain/entities/reminder.dart';

class ReminderPickerDialog extends StatefulWidget {
  const ReminderPickerDialog({super.key});

  @override
  State<ReminderPickerDialog> createState() => _ReminderPickerDialogState();
}

class _ReminderPickerDialogState extends State<ReminderPickerDialog> {
  TimeOfDay? _selectedTime;
  final Map<String, bool> _days = {
    'Mon': false,
    'Tue': false,
    'Wed': false,
    'Thu': false,
    'Fri': false,
    'Sat': false,
    'Sun': false,
  };
  final TextEditingController _messageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Add Reminder",
            style: TextStyle(color: Colors.white, fontSize: 22),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _selectedTime ?? TimeOfDay.now(),
              );
              if (picked != null) {
                setState(() => _selectedTime = picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.white70),
                  const SizedBox(width: 10),
                  Text(
                    _selectedTime != null
                        ? _selectedTime!.format(context)
                        : "Pick Time",
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Notify on days",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: _days.keys.map((day) {
              return FilterChip(
                label: Text(
                  day,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                selected: _days[day]!,
                onSelected: (selected) =>
                    setState(() => _days[day] = selected),
                backgroundColor: const Color(0xFF1A1A1A),
                selectedColor: Colors.blueAccent,
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _messageController,
            maxLength: 40,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "What should the reminder say?",
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_selectedTime != null) {
                    Navigator.pop(
                      context,
                      Reminder(
                        time: _selectedTime!,
                        days: Map.from(_days),
                        message: _messageController.text,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
                child: const Text("Save"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

