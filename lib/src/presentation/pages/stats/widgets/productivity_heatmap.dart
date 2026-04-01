import 'package:flutter/material.dart';
import '../models/daily_completion.dart';
import 'stats_constants.dart';

/// Feature 4: GitHub-style 30-day productivity heatmap showing daily
/// completion rates as colored squares.
class ProductivityHeatmap extends StatelessWidget {
  final List<DailyCompletion> data;
  final int perfectDays;

  const ProductivityHeatmap({
    super.key,
    required this.data,
    required this.perfectDays,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Productivity Heatmap',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              if (perfectDays > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kStatsGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 14, color: kStatsGreen),
                      const SizedBox(width: 4),
                      Text('$perfectDays perfect',
                          style: const TextStyle(
                              color: kStatsGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Last 30 days',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
          const SizedBox(height: 16),
          // 6 columns x 5 rows grid
          _buildGrid(),
          const SizedBox(height: 12),
          _buildColorLegend(),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    // Fill to 30 entries
    final cells = List<DailyCompletion>.from(data);
    while (cells.length < 30) {
      cells.insert(
          0, DailyCompletion(date: _epoch, completionRate: 0, totalTasks: 0));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: 30,
      itemBuilder: (context, index) {
        final cell = cells[index];
        final color = _colorForRate(cell);
        // Show day number on hover/tooltip
        return Tooltip(
          message: cell.totalTasks > 0
              ? '${cell.date.day}/${cell.date.month}: ${(cell.completionRate * 100).round()}%'
              : '${cell.date.day}/${cell.date.month}: No tasks',
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );
      },
    );
  }

  Color _colorForRate(DailyCompletion d) {
    if (d.totalTasks == 0) {
      return Colors.white.withValues(alpha: 0.04);
    }
    final rate = d.completionRate;
    if (rate == 1.0) return kStatsGreen;
    if (rate >= 0.7) return kStatsGreen.withValues(alpha: 0.6);
    if (rate >= 0.3) return Colors.orangeAccent.withValues(alpha: 0.5);
    if (rate > 0) return kStatsRed.withValues(alpha: 0.4);
    return kStatsRed.withValues(alpha: 0.25);
  }

  Widget _buildColorLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Less ',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35), fontSize: 10)),
        _legendSquare(Colors.white.withValues(alpha: 0.04)),
        _legendSquare(kStatsRed.withValues(alpha: 0.3)),
        _legendSquare(Colors.orangeAccent.withValues(alpha: 0.5)),
        _legendSquare(kStatsGreen.withValues(alpha: 0.6)),
        _legendSquare(kStatsGreen),
        Text(' More',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35), fontSize: 10)),
      ],
    );
  }

  Widget _legendSquare(Color color) {
    return Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

final _epoch = DateTime(2000);
