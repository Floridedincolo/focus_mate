import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/usage_stats_providers.dart';
import 'stats_constants.dart';

/// Permission request banner shown when usage data access is not granted.
class StatsPermissionBanner extends ConsumerWidget {
  const StatsPermissionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orangeAccent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Usage Data Access',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enable permission to see your screen time stats.',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              ref.read(usageStatsDsProvider).requestUsagePermission();
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.orangeAccent.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Enable',
              style: TextStyle(
                  color: Colors.orangeAccent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Error card with retry button.
class StatsErrorCard extends ConsumerWidget {
  final Object error;

  const StatsErrorCard({super.key, required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
          const SizedBox(height: 12),
          Text('Failed to load data',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => ref.invalidate(usageStatsProvider),
            child: const Text('Retry', style: TextStyle(color: kStatsAccent)),
          ),
        ],
      ),
    );
  }
}

/// Placeholder shown when usage data permission is missing.
class StatsNoPermissionPlaceholder extends StatelessWidget {
  const StatsNoPermissionPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.bar_chart_rounded,
              size: 56, color: kStatsAccent.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('Enable usage data access\nto see your statistics.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                  height: 1.5)),
        ],
      ),
    );
  }
}

/// Loading skeleton for task stats section.
class TaskStatsLoading extends StatelessWidget {
  const TaskStatsLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(color: kStatsGreen, strokeWidth: 3),
        ),
      ),
    );
  }
}
