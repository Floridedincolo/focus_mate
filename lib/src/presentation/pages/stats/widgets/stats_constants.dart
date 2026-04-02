import 'package:flutter/material.dart';

const kStatsBg = Color(0xFF0D0D0D);
const kStatsCard = Color(0xFF1A1A1A);
const kStatsAccent = Color(0xFF6366F1);
const kStatsAccent2 = Color(0xFF8B5CF6);
const kStatsGreen = Color(0xFF34D399);
const kStatsRed = Color(0xFFEF4444);
const kStatsPurple = Color(0xFFA855F7); // distracting
const kStatsBlue = Color(0xFF60A5FA);   // neutral

String formatMinutes(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}
