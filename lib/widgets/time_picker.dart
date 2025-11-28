import 'package:flutter/material.dart';
class TimePicker extends StatefulWidget {
  TimeOfDay? initialTime;
  String label;
  final void Function(TimeOfDay) onTimeSelected;//functie care primeste un timeofday ca parametru si o voi ca parametru ca sa se execute de fiecre data cand dau pick la ceva
  TimePicker({super.key, this.initialTime,required this.label, required this.onTimeSelected});

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
      onTap:() async{
final TimeOfDay now =TimeOfDay.now();
final TimeOfDay? picked = await showTimePicker(
  context: context,
  initialTime: _selectedTime ?? now,
  builder: (context, child) {
    // Dark theme picker
    return Theme(
        data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.cyan,
              surface: Color(0xFF1A1A1A),), dialogTheme: DialogThemeData(backgroundColor: Color(0xFF0D0D0D)),
        ),
        child: child!
    );
  });
if(picked!=null){
  setState(() {
    _selectedTime = picked;//sa apara in field
  });
  widget.onTimeSelected(picked);
}
      },
      child:AbsorbPointer(//ca sa nu primeasca click copiii widgetului(sa nu pot da input la text field)
        child: TextField(
          readOnly: true,
          controller: TextEditingController(//controlez textu din textfield deci o sa fisez ce ora am dat pick
            text: _selectedTime != null
                ? _selectedTime!.format(context)
                : "",
          ),
          decoration:InputDecoration(
            hintText: widget.label,
            hintStyle: TextStyle(color: Colors.white54),
            suffixIcon: Icon(Icons.alarm, color: Colors.white54),
            filled:true,
            fillColor: Color(0xFF1A1A1A),
            border:OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          style: TextStyle(color: Colors.white),
        ),
      )
    );
  }
}
