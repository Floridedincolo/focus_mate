import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'stats_constants.dart';

/// Entry for an app's usage change between periods.
class AppTrendEntry {
  final String appName;
  final String iconBase64;
  final int deltaMinutes; // negative = decreased, positive = increased

  const AppTrendEntry({
    required this.appName,
    required this.iconBase64,
    required this.deltaMinutes,
  });
}

// ─── Layout constants ────────────────────────────────────────
const double _kIconSize = 40;
const double _kIconOverlap = _kIconSize / 2; // half outside the bar
const double _kBarRadius = 16;
const List<double> _kBarHeights = [140, 115, 95]; // rank 1, 2, 3

/// "Top time-savers" card: apps where usage decreased the most.
class TopTimeSaversCard extends StatelessWidget {
  final List<AppTrendEntry> entries;

  const TopTimeSaversCard({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return _PodiumCard(
      title: 'Top Time-savers',
      subtitle: 'In these apps you spent less time',
      headerIcon: Icons.south_east,
      headerIconColor: kStatsGreen,
      entries: entries,
      valueColor: kStatsGreen,
      showRankNumbers: true,
    );
  }
}

/// "Top Increase" card: apps where usage increased the most.
class TopIncreaseCard extends StatelessWidget {
  final List<AppTrendEntry> entries;

  const TopIncreaseCard({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return _PodiumCard(
      title: 'Top Increase',
      subtitle: 'These apps took more of your time',
      headerIcon: Icons.north_east,
      headerIconColor: kStatsRed,
      entries: entries,
      valueColor: kStatsRed,
      showRankNumbers: false,
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  Main card
// ═════════════════════════════════════════════════════════════
class _PodiumCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData headerIcon;
  final Color headerIconColor;
  final List<AppTrendEntry> entries;
  final Color valueColor;
  final bool showRankNumbers;

  const _PodiumCard({
    required this.title,
    required this.subtitle,
    required this.headerIcon,
    required this.headerIconColor,
    required this.entries,
    required this.valueColor,
    required this.showRankNumbers,
  });

  @override
  Widget build(BuildContext context) {
    final count = min(entries.length, 3);
    // Total height = tallest bar + the icon overlap on top
    final totalHeight = _kBarHeights[0] + _kIconOverlap;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                        )),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: headerIconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(headerIcon, color: headerIconColor, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Podium row ──
          SizedBox(
            height: totalHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(count, (i) {
                final item = _PodiumItem(
                  rank: i + 1,
                  entry: entries[i],
                  barHeight: _kBarHeights[i],
                  valueColor: valueColor,
                  showRankNumber: showRankNumbers,
                );
                if (i == 0) return Expanded(child: item);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: item,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  Single podium column (icon floating on top edge)
// ═════════════════════════════════════════════════════════════
class _PodiumItem extends StatelessWidget {
  final int rank;
  final AppTrendEntry entry;
  final double barHeight;
  final Color valueColor;
  final bool showRankNumber;

  const _PodiumItem({
    required this.rank,
    required this.entry,
    required this.barHeight,
    required this.valueColor,
    required this.showRankNumber,
  });

  @override
  Widget build(BuildContext context) {
    final prefix = entry.deltaMinutes < 0 ? '-' : '+';
    final absMin = entry.deltaMinutes.abs();

    // Stack lets the icon sit half-in / half-out of the bar
    return SizedBox(
      height: barHeight + _kIconOverlap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── The bar ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: barHeight,
            child: Container(
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(_kBarRadius)),
                // Subtle inner-shadow / gradient for depth
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.03),
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 10), // space below floating icon
                  if (showRankNumber) _buildRankWithLaurel() else _buildArrow(),
                  const SizedBox(height: 6),
                  Text(
                    '$prefix${formatMinutes(absMin)}',
                    style: TextStyle(
                      color: valueColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Floating app icon (centered on top edge of bar) ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(child: _buildAppIcon()),
          ),
        ],
      ),
    );
  }

  // ── Rank number wrapped in laurel wreath ──
  Widget _buildRankWithLaurel() {
    return SizedBox(
      width: 64,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left laurel branch
          Positioned(
            left: 0,
            child: Text(
              '\u{1F33F}', // 🌿 herb / branch emoji
              style: TextStyle(
                fontSize: 22,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              textScaler: TextScaler.noScaling,
            ),
          ),
          // Right laurel branch (mirrored)
          Positioned(
            right: 0,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..scale(-1.0, 1.0),
              child: Text(
                '\u{1F33F}',
                style: TextStyle(
                  fontSize: 22,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                textScaler: TextScaler.noScaling,
              ),
            ),
          ),
          // Rank number
          Text(
            '$rank',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.25),
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ── Arrow icon for "Top Increase" card ──
  Widget _buildArrow() {
    return Icon(
      Icons.north_east_rounded,
      color: valueColor.withValues(alpha: 0.6),
      size: 32,
    );
  }

  // ── App icon (base64 or fallback) ──
  Widget _buildAppIcon() {
    Widget icon;
    if (entry.iconBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(entry.iconBase64);
        icon = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            width: _kIconSize,
            height: _kIconSize,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackIcon(),
          ),
        );
      } catch (_) {
        icon = _fallbackIcon();
      }
    } else {
      icon = _fallbackIcon();
    }

    // Outer ring / shadow to make the icon pop against the bar
    return Container(
      width: _kIconSize + 4,
      height: _kIconSize + 4,
      decoration: BoxDecoration(
        color: kStatsCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(child: icon),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      width: _kIconSize,
      height: _kIconSize,
      decoration: BoxDecoration(
        color: kStatsAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          entry.appName.isNotEmpty ? entry.appName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: kStatsAccent,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
