import 'package:flutter/material.dart';

class TimePicker extends StatefulWidget {
  final TimeOfDay? initialTime;
  final String label;
  final void Function(TimeOfDay) onTimeSelected;
  final TimeOfDay? minimumTime;

  const TimePicker({
    super.key,
    this.initialTime,
    required this.label,
    required this.onTimeSelected,
    this.minimumTime,
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

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showModalBottomSheet<TimeOfDay>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => _ScrollTimePickerSheet(
            initialTime: _selectedTime ?? TimeOfDay.now(),
            minimumTime: widget.minimumTime,
          ),
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
            text: _selectedTime != null ? _formatTime(_selectedTime!) : "",
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

/// Bottom sheet with two scroll wheels for hours (0-23) and minutes (0-59).
class _ScrollTimePickerSheet extends StatefulWidget {
  final TimeOfDay initialTime;
  final TimeOfDay? minimumTime;

  const _ScrollTimePickerSheet({required this.initialTime, this.minimumTime});

  @override
  State<_ScrollTimePickerSheet> createState() => _ScrollTimePickerSheetState();
}

class _ScrollTimePickerSheetState extends State<_ScrollTimePickerSheet> {
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;
  late int _hour;
  late int _minute;
  String? _error;

  // Large multiplier for "infinite" cyclic scrolling
  static const int _cycleMultiplier = 100;

  int get _minMinutes =>
      widget.minimumTime != null
          ? widget.minimumTime!.hour * 60 + widget.minimumTime!.minute
          : -1;

  bool get _isValid => (_hour * 60 + _minute) > _minMinutes;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    // If initial time is below minimum, bump to minimum
    if (!_isValid && widget.minimumTime != null) {
      _hour = widget.minimumTime!.hour;
      _minute = widget.minimumTime!.minute;
    }

    // Start in the middle of the virtual list for seamless cycling
    _hourController = FixedExtentScrollController(
      initialItem: _cycleMultiplier ~/ 2 * 24 + _hour,
    );
    _minuteController = FixedExtentScrollController(
      initialItem: _cycleMultiplier ~/ 2 * 60 + _minute,
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header with Cancel / Done
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white54, fontSize: 16)),
                ),
                const Text('Select Time',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                TextButton(
                  onPressed: _isValid
                      ? () {
                          Navigator.pop(
                              context, TimeOfDay(hour: _hour, minute: _minute));
                        }
                      : () {
                          setState(() => _error = 'Must be after ${widget.minimumTime!.hour.toString().padLeft(2, '0')}:${widget.minimumTime!.minute.toString().padLeft(2, '0')}');
                        },
                  child: Text('Done',
                      style: TextStyle(
                          color: _isValid ? Colors.blueAccent : Colors.white38,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          // Scroll wheels
          SizedBox(
            height: 200,
            child: Stack(
              children: [
                // Selection highlight
                Center(
                  child: Container(
                    height: 44,
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Hours wheel
                    SizedBox(
                      width: 80,
                      child: ListWheelScrollView.useDelegate(
                        controller: _hourController,
                        itemExtent: 44,
                        perspective: 0.003,
                        diameterRatio: 1.5,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _hour = index % 24;
                            _error = null;
                          });
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          builder: (context, index) {
                            final h = index % 24;
                            final isSelected = h == _hour;
                            return Center(
                              child: Text(
                                h.toString().padLeft(2, '0'),
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white38,
                                  fontSize: isSelected ? 24 : 20,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            );
                          },
                          childCount: 24 * _cycleMultiplier,
                        ),
                      ),
                    ),

                    // Colon separator
                    const Text(':',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600)),

                    // Minutes wheel
                    SizedBox(
                      width: 80,
                      child: ListWheelScrollView.useDelegate(
                        controller: _minuteController,
                        itemExtent: 44,
                        perspective: 0.003,
                        diameterRatio: 1.5,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _minute = index % 60;
                            _error = null;
                          });
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          builder: (context, index) {
                            final m = index % 60;
                            final isSelected = m == _minute;
                            return Center(
                              child: Text(
                                m.toString().padLeft(2, '0'),
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white38,
                                  fontSize: isSelected ? 24 : 20,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            );
                          },
                          childCount: 60 * _cycleMultiplier,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
