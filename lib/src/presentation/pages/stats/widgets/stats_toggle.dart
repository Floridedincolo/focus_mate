import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/usage_stats_providers.dart';
import 'stats_constants.dart';

/// Main period toggle: Day / Week / Trend.
class StatsToggle extends ConsumerWidget {
  const StatsToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(usageStatsDaysProvider);
    final isTrend = ref.watch(isTrendModeProvider);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _ToggleItem(
            label: 'Day',
            isSelected: !isTrend && days == 1,
            onTap: () {
              ref.read(isTrendModeProvider.notifier).state = false;
              ref.read(usageStatsDaysProvider.notifier).state = 1;
              ref.read(dateOffsetProvider.notifier).state = 0;
            },
          ),
          _ToggleItem(
            label: 'Week',
            isSelected: !isTrend && days == 7,
            onTap: () {
              ref.read(isTrendModeProvider.notifier).state = false;
              ref.read(usageStatsDaysProvider.notifier).state = 7;
              ref.read(dateOffsetProvider.notifier).state = 0;
            },
          ),
          _ToggleItem(
            label: 'Trend',
            isSelected: isTrend,
            onTap: () {
              ref.read(isTrendModeProvider.notifier).state = true;
              final trendDays = ref.read(trendPeriodProvider);
              ref.read(usageStatsDaysProvider.notifier).state = trendDays;
              ref.read(dateOffsetProvider.notifier).state = 0;
            },
          ),
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
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
