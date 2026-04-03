import 'package:flutter/material.dart';
import '../../../domain/entities/extracted_class.dart';

const _kDayOptions = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class EditClassDialog extends StatefulWidget {
  final ExtractedClass extractedClass;

  const EditClassDialog({super.key, required this.extractedClass});

  static Future<ExtractedClass?> show(
    BuildContext context,
    ExtractedClass extractedClass,
  ) {
    return showDialog<ExtractedClass>(
      context: context,
      builder: (_) => EditClassDialog(extractedClass: extractedClass),
    );
  }

  @override
  State<EditClassDialog> createState() => _EditClassDialogState();
}

class _EditClassDialogState extends State<EditClassDialog> {
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _roomCtrl;
  late String _day;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  @override
  void initState() {
    super.initState();
    final c = widget.extractedClass;
    _subjectCtrl = TextEditingController(text: c.subject);
    _roomCtrl = TextEditingController(text: c.room ?? '');
    _day = c.day;
    _startTime = c.startTime;
    _endTime = c.endTime;
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.blueAccent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF141414),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Edit Class',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _subjectCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Subject'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _kDayOptions.contains(_day) ? _day : _kDayOptions.first,
              dropdownColor: const Color(0xFF1E1E1E),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _inputDecoration('Day'),
              items: _kDayOptions
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _day = v);
              },
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _TimeTile(
                    label: 'Start',
                    time: _startTime,
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeTile(
                    label: 'End',
                    time: _endTime,
                    onTap: () => _pickTime(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _roomCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Room (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('Cancel', style: TextStyle(color: Colors.white38)),
        ),
        GestureDetector(
          onTap: _save,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Save',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ),
        ),
      ],
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _save() {
    final subject = _subjectCtrl.text.trim();
    if (subject.isEmpty) return;

    final room = _roomCtrl.text.trim();
    final updated = widget.extractedClass.copyWith(
      subject: subject,
      day: _day,
      startTime: _startTime,
      endTime: _endTime,
      room: room.isEmpty ? null : room,
    );
    Navigator.pop(context, updated);
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimeTile({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 4),
            Text(text,
                style: const TextStyle(color: Colors.white, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
