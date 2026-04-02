import 'package:flutter/material.dart';
import '../models/calendar_icon_data.dart';

class CalendarIconWidget extends StatelessWidget {
  final CalendarIconData calendarIconData;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  const CalendarIconWidget({
    super.key,
    required this.calendarIconData,
    this.isSelected = false,
    this.isToday = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Weekday label
            Text(
              calendarIconData.weekday.substring(0, 3).toUpperCase(),
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            // Day number with circle background when selected
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                calendarIconData.day.toString(),
                style: TextStyle(
                  color: isSelected ? const Color(0xFF0D0D0D) : Colors.white70,
                  fontSize: 18,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Today indicator dot
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isToday && !isSelected ? 1.0 : 0.0,
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
