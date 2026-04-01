import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/service_locator.dart';
import '../../domain/usecases/accessibility_usecases.dart';
import '../providers/block_template_providers.dart';
import '../providers/task_providers.dart';
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pushNamed('/add_task');
        },
        backgroundColor: accentColor,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: bottomBarColor,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home,
                label: 'Home',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.visibility,
                label: 'Focus',
                index: 1,
              ),
              const SizedBox(width: 48),
              _buildNavItem(
                icon: Icons.bar_chart,
                label: 'Stats',
                index: 2,
              ),
              _buildNavItem(
                icon: Icons.person,
                label: 'Profile',
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isActive = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? accentColor : Colors.grey,
            ),
            Text(
              label,
              style: TextStyle(
                color: isActive ? accentColor : Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

