import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/service_locator.dart';
import '../../domain/usecases/accessibility_usecases.dart';
import '../providers/block_template_providers.dart';
import '../providers/task_providers.dart';
import '../providers/usage_stats_providers.dart';
import 'home.dart';
import 'focus_page.dart';
import 'stats/stats_page.dart';
import 'profile.dart';

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  int _selectedIndex = 0;
  // Sentinel so the very first evaluation (even when currentKey is null)
  // still triggers ClearBlockingUseCase to wipe stale SharedPreferences.
  String? _lastAppliedFingerprint = '__uninitialized__';

  final bottomBarColor = const Color(0xFF1A1A1A);
  final accentColor = Colors.blueAccent;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Refresh stats data whenever the user navigates to the Stats tab
    if (index == 2) {
      ref.invalidate(usageStatsProvider);
      ref.invalidate(enrichedUsageStatsProvider);
      ref.invalidate(taskStatsProvider);
      ref.invalidate(heatmapDataProvider);
    }
  }

  /// Watches the currently active task and applies/clears the blocking template
  /// globally, regardless of which tab is selected.
  void _watchAndApplyActiveTask() {
    final activeTask = ref.watch(currentActiveTaskProvider);
    final templateId = activeTask?.blockTemplateId;
    final templates = ref.watch(blockTemplatesProvider).valueOrNull;

    String? fingerprint;
    if (templateId != null && templates != null) {
      final t = templates.where((t) => t.id == templateId).firstOrNull;
      if (t != null) {
        // Include activeTask.id so two tasks sharing the same template
        // still trigger a re-apply with the correct task name.
        fingerprint =
            '${activeTask?.id}_${t.id}_${t.isWhitelist}_${t.packages.join(",")}';
      }
    }

    final currentKey = fingerprint ?? templateId;
    if (currentKey == _lastAppliedFingerprint) return;
    _lastAppliedFingerprint = currentKey;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (templateId != null && templates != null) {
        final template =
            templates.where((t) => t.id == templateId).firstOrNull;
        if (template != null) {
          await getIt<ApplyBlockingTemplateUseCase>()(
            packages: template.packages,
            isWhitelist: template.isWhitelist,
            taskName: activeTask?.title,
          );
        }
      } else if (templateId == null) {
        await getIt<ClearBlockingUseCase>()();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Global task monitoring — runs on every rebuild regardless of tab
    _watchAndApplyActiveTask();

    final pages = [
      const Home(),
      const FocusPage(),
      const StatsPage(),
      const Profile(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      floatingActionButton: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor,
              accentColor.withValues(alpha: 0.7),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => Navigator.of(context).pushNamed('/add_task'),
            child: const Icon(Icons.add, color: Colors.white, size: 26),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _buildNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.visibility_outlined,
                  activeIcon: Icons.visibility,
                  label: 'Focus',
                  index: 1,
                ),
                const SizedBox(width: 64),
                _buildNavItem(
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart_rounded,
                  label: 'Stats',
                  index: 2,
                ),
                _buildNavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile',
                  index: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isActive = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onItemTapped(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey('${index}_$isActive'),
                color: isActive ? Colors.white : Colors.white30,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white30,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

