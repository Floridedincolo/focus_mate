import 'package:flutter/material.dart';
import '../../domain/entities/reminder.dart';
import 'time_picker.dart';

class ReminderPickerDialog extends StatefulWidget {
  final bool isOneTime;

  const ReminderPickerDialog({super.key, this.isOneTime = false});

  @override
  State<ReminderPickerDialog> createState() => _ReminderPickerDialogState();
}

class _ReminderPickerDialogState extends State<ReminderPickerDialog> {
  TimeOfDay? _selectedTime;
  ReminderType _type = ReminderType.notification;
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

  Widget _typeOption({
    required ReminderType type,
    required IconData icon,
    required String label,
  }) {
    final selected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? Colors.blueAccent : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? Colors.white : Colors.white70, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
          Row(
            children: [
              _typeOption(
                type: ReminderType.notification,
                icon: Icons.notifications_outlined,
                label: "Notification",
              ),
              const SizedBox(width: 10),
              _typeOption(
                type: ReminderType.alarm,
                icon: Icons.alarm,
                label: "Alarm",
              ),
            ],
          ),
          const SizedBox(height: 20),
          TimePicker(
            label: "Pick Time",
            initialTime: _selectedTime,
            onTimeSelected: (picked) =>
                setState(() => _selectedTime = picked),
          ),
          if (!widget.isOneTime) ...[
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
          ],
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
                        type: _type,
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

