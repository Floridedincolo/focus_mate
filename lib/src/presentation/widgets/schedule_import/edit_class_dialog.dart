import 'package:flutter/material.dart';
import '../../../domain/entities/extracted_class.dart';

/// Days the app recognises (must match the abbreviations used in [ExtractedClass.day]).
const _kDayOptions = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Dialog that lets the user manually correct an AI-extracted class occurrence.
///
/// Returns the updated [ExtractedClass] via [Navigator.pop], or `null` if
/// the user cancels.
class EditClassDialog extends StatefulWidget {
  final ExtractedClass extractedClass;

  const EditClassDialog({super.key, required this.extractedClass});

  /// Convenience launcher — shows the dialog and returns the result.
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Class'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Subject name
            TextField(
              controller: _subjectCtrl,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),

            // Day dropdown
            DropdownButtonFormField<String>(
              value: _kDayOptions.contains(_day) ? _day : _kDayOptions.first,
              decoration: const InputDecoration(
                labelText: 'Day',
                border: OutlineInputBorder(),
              ),
              items: _kDayOptions
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _day = v);
              },
            ),
            const SizedBox(height: 12),

            // Start / End time row
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

            // Room
            TextField(
              controller: _roomCtrl,
              decoration: const InputDecoration(
                labelText: 'Room (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
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

/// Small helper widget that displays a time value and is tappable.
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(text),
      ),
    );
  }
}

