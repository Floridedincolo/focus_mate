import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/usage_stats_providers.dart';
import 'stats_constants.dart';

/// Sub-toggle for Trend view: 1M / 3M / Max.
class TrendSubToggle extends ConsumerWidget {
  const TrendSubToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(trendPeriodProvider);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _Item(label: '1M', value: 30, current: period),
          _Item(label: '3M', value: 90, current: period),
          _Item(label: 'Max', value: 365, current: period),
        ],
      ),
    );
  }
}

class _Item extends ConsumerWidget {
  final String label;
  final int value;
  final int current;

  const _Item({
    required this.label,
    required this.value,
    required this.current,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref.read(trendPeriodProvider.notifier).state = value;
          ref.read(usageStatsDaysProvider.notifier).state = value;
        },
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
