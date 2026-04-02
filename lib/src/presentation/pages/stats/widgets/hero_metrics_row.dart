import 'package:flutter/material.dart';
import '../models/enriched_usage_stats.dart';
import 'stats_constants.dart';

/// Feature 1 + Feature 5: Three hero metric cards (screen time, focus time,
/// distractions prevented) with optional trend arrows.
///
/// When [selectedHour] is provided, all three cards update to show
/// per-hour values instead of totals.
/// When [selectedScreenTimeOverride] is provided (daily chart selection),
/// only screen time updates to that value.
class HeroMetricsRow extends StatelessWidget {
  final EnrichedUsageStats stats;
  final int days;
  final int? selectedHour;
  final int? selectedScreenTimeOverride;

  const HeroMetricsRow({
    super.key,
    required this.stats,
    required this.days,
    this.selectedHour,
    this.selectedScreenTimeOverride,
  });

  @override
  Widget build(BuildContext context) {
    final hasHourSelection = selectedHour != null;
    final h = selectedHour ?? 0;
    final hasDaySelection = selectedScreenTimeOverride != null;

    String screenTimeValue;
    if (hasHourSelection) {
      screenTimeValue = formatMinutes(stats.hourlyUsage[h]);
    } else if (hasDaySelection) {
      screenTimeValue = formatMinutes(selectedScreenTimeOverride!);
    } else {
      screenTimeValue = formatMinutes(stats.totalScreenTimeMinutes);
    }

    final focusValue = hasHourSelection && h < stats.hourlyFocusMinutes.length
        ? formatMinutes(stats.hourlyFocusMinutes[h])
        : formatMinutes(stats.focusTimeMinutes);

    final blockedValue = hasHourSelection && h < stats.hourlyBlockedDistractions.length
        ? '${stats.hourlyBlockedDistractions[h]}'
        : '${stats.preventedDistractions}';

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            value: screenTimeValue,
            label: 'Screen Time',
            icon: Icons.phone_android,
            iconColor: kStatsAccent,
            trendPercentage: (hasHourSelection || hasDaySelection) ? null : stats.trendPercentage,
            trendInverted: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            value: focusValue,
            label: 'Focus Time',
            icon: Icons.shield_outlined,
            iconColor: kStatsGreen,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            value: blockedValue,
            label: 'Blocked',
            icon: Icons.block,
            iconColor: kStatsPurple,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color iconColor;
  final double? trendPercentage;
  final bool trendInverted;

  const _MetricCard({
    required this.value,
    required this.label,
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
        ],
      ),
    );
  }

  Widget _buildTrendBadge() {
    final pct = trendPercentage!;
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
