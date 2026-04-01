import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/usage_stats_providers.dart';
import 'stats_constants.dart';

/// Period toggle: Today / This Week / This Month (Feature 5).
class StatsToggle extends ConsumerWidget {
  const StatsToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(usageStatsDaysProvider);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _ToggleItem(label: 'Today', days: 1, currentDays: days),
          _ToggleItem(label: 'This Week', days: 7, currentDays: days),
          _ToggleItem(label: 'This Month', days: 30, currentDays: days),
        ],
      ),
    );
  }
}

class _ToggleItem extends ConsumerWidget {
  final String label;
  final int days;
  final int currentDays;

  const _ToggleItem({
    required this.label,
    required this.days,
    required this.currentDays,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = currentDays == days;
    return Expanded(
      child: GestureDetector(
        onTap: () =>
            ref.read(usageStatsDaysProvider.notifier).state = days,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? kStatsAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white54,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
