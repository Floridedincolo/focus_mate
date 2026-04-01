import 'package:flutter/material.dart';
import '../models/enriched_usage_stats.dart';
import 'stats_constants.dart';

/// Feature 1 + Feature 5: Three hero metric cards (screen time, focus time,
/// distractions prevented) with optional trend arrows.
class HeroMetricsRow extends StatelessWidget {
  final EnrichedUsageStats stats;
  final int days;

  const HeroMetricsRow({
    super.key,
    required this.stats,
    required this.days,
  });

  String get _periodLabel {
    switch (days) {
      case 1:
        return 'today';
      case 7:
        return 'this week';
      default:
        return 'this month';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            value: formatMinutes(stats.totalScreenTimeMinutes),
            label: 'Screen Time',
            subtitle: _periodLabel,
            icon: Icons.phone_android,
            iconColor: kStatsAccent,
            trendPercentage: stats.trendPercentage,
            trendInverted: true, // For screen time, going down is good
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            value: formatMinutes(stats.focusTimeMinutes),
            label: 'Focus Time',
            subtitle: _periodLabel,
            icon: Icons.shield_outlined,
            iconColor: kStatsGreen,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            value: '${stats.preventedDistractions}',
            label: 'Blocked',
            subtitle: 'distractions',
            icon: Icons.block,
            iconColor: kStatsRed,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final double? trendPercentage;
  final bool trendInverted;

  const _MetricCard({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.trendPercentage,
    this.trendInverted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor.withValues(alpha: 0.7)),
              const Spacer(),
              if (trendPercentage != null) _buildTrendBadge(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendBadge() {
    final pct = trendPercentage!;
    // For screen time: negative trend (less time) = good = green
    final isGood = trendInverted ? pct < 0 : pct > 0;
    final color = isGood ? kStatsGreen : kStatsRed;
    final arrow = pct < 0 ? Icons.trending_down : Icons.trending_up;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(arrow, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            '${pct.abs().round()}%',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
