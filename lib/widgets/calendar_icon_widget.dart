import 'package:flutter/material.dart';

import '../models/calendar_icon_data.dart';

class CalendarIconWidget extends StatelessWidget {
  final CalendarIconData calendarIconData;
  final bool isSelected;
  final VoidCallback onTap;
  const CalendarIconWidget({super.key, required this.calendarIconData, this.isSelected = false,required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: isSelected ? Colors.blueAccent :Colors.grey[800],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: isSelected ? BorderSide(color: Colors.amberAccent, width: 2) : BorderSide.none,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(calendarIconData.day.toString(), style: TextStyle(color: Colors.white, fontSize: 30)),
            Text(calendarIconData.weekday.substring(0,3), style: TextStyle(color: Colors.white)),
        ]
      )
      ),
    );
  }
}
