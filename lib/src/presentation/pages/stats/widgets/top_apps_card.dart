import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/app_category.dart';
import '../models/enriched_usage_stats.dart';
import 'stats_constants.dart';

/// Top apps list with usage bars and category indicator badges.
class TopAppsCard extends StatelessWidget {
  final List<AppUsageEntry> topApps;

  const TopAppsCard({super.key, required this.topApps});

  @override
  Widget build(BuildContext context) {
    if (topApps.isEmpty) return const SizedBox.shrink();

    final maxMinutes =
        topApps.first.usageMinutes > 0 ? topApps.first.usageMinutes : 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Most Used Apps',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          ...topApps.map((app) {
            final fraction =
                maxMinutes > 0 ? app.usageMinutes / maxMinutes : 0.0;
            final barColor = _barColorForCategory(app.category);

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  _buildAppIcon(app),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(app.appName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            _buildCategoryBadge(app.category),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: fraction.clamp(0.0, 1.0),
                            minHeight: 4,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.06),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(barColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(formatMinutes(app.usageMinutes),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _barColorForCategory(AppCategory category) {
    switch (category) {
      case AppCategory.productive:
        return kStatsGreen;
      case AppCategory.distracting:
        return kStatsPurple;
      case AppCategory.neutral:
        return kStatsBlue;
    }
  }

  Widget _buildCategoryBadge(AppCategory category) {
    final (label, color) = switch (category) {
      AppCategory.productive => ('Productive', kStatsGreen),
      AppCategory.distracting => ('Distracting', kStatsPurple),
      AppCategory.neutral => ('Neutral', kStatsBlue),
    };
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildAppIcon(AppUsageEntry app) {
    if (app.iconBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(app.iconBase64);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(bytes,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallbackIcon(app.appName)),
        );
      } catch (_) {
        return _buildFallbackIcon(app.appName);
      }
    }
    return _buildFallbackIcon(app.appName);
  }

  Widget _buildFallbackIcon(String appName) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: kStatsAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          appName.isNotEmpty ? appName[0].toUpperCase() : '?',
          style: const TextStyle(
              color: kStatsAccent, fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }
}
