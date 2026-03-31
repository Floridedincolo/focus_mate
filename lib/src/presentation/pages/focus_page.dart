import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/service_locator.dart';
import '../../domain/entities/app_block_template.dart';
import '../../domain/repositories/block_template_repository.dart';
import '../../domain/usecases/accessibility_usecases.dart';
import '../providers/block_template_providers.dart';
import '../providers/task_providers.dart';
import 'create_template_screen.dart';

class FocusPage extends ConsumerStatefulWidget {
  const FocusPage({super.key});

  @override
  ConsumerState<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends ConsumerState<FocusPage>
    with WidgetsBindingObserver {
  bool _isAccessibilityEnabled = false;
  bool _hasOverlayPermission = false;

  // Track the last applied template to avoid redundant calls
  String? _lastAppliedTemplateId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 1000), () async {
        await _checkPermissions();
      });
    }
  }

  Future<void> _checkPermissions() async {
    final accessibilityEnabled =
        await getIt<CheckAccessibilityUseCase>()();
    final overlayEnabled =
        await getIt<CheckOverlayPermissionUseCase>()();

    if (mounted) {
      setState(() {
        _isAccessibilityEnabled = accessibilityEnabled;
        _hasOverlayPermission = overlayEnabled;
      });
    }
  }

  Future<void> _deleteTemplate(AppBlockTemplate template) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Template',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${template.name}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await getIt<BlockTemplateRepository>().deleteTemplate(template.id);
      ref.invalidate(blockTemplatesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(blockTemplatesProvider);

    // Reactive blocking: watch active task and apply its template
    _watchAndApplyActiveTask();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      floatingActionButton: FloatingActionButton(
        heroTag: 'focus_page_fab',
        backgroundColor: Colors.blueAccent,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateTemplateScreen()),
          );
          ref.invalidate(blockTemplatesProvider);
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  "Focus Mode",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Create blocking profiles for your tasks.",
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
                const SizedBox(height: 20),

                // Permission banners
                if (!_isAccessibilityEnabled) _buildAccessibilityBanner(),
                if (!_hasOverlayPermission) _buildOverlayBanner(),

                const SizedBox(height: 12),

                // Templates list
                templatesAsync.when(
                  data: (templates) {
                    if (templates.isEmpty) {
                      return _buildEmptyState();
                    }
                    return Column(
                      children: templates
                          .map((t) => _buildTemplateCard(t))
                          .toList(),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  ),
                  error: (e, _) => Text('Error: $e',
                      style: const TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _watchAndApplyActiveTask() {
    final activeTask = ref.watch(currentActiveTaskProvider);
    final templateId = activeTask?.blockTemplateId;

    // Also watch templates so edits (whitelist<->blacklist, app changes)
    // trigger a re-apply even when the templateId hasn't changed.
    final templates = ref.watch(blockTemplatesProvider).valueOrNull;

    // Build a fingerprint that changes when either the active template ID
    // or the template contents change.
    String? fingerprint;
    if (templateId != null && templates != null) {
      final t = templates.where((t) => t.id == templateId).firstOrNull;
      if (t != null) {
        fingerprint = '${t.id}_${t.isWhitelist}_${t.packages.join(',')}';
      }
    }

    final currentKey = fingerprint ?? templateId;
    if (currentKey == _lastAppliedTemplateId) return;
    _lastAppliedTemplateId = currentKey;

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

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Icon(Icons.shield_outlined, color: Colors.grey[600], size: 56),
          const SizedBox(height: 16),
          const Text(
            'No Focus Profiles yet',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first blocking template.',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(AppBlockTemplate template) {
    final typeLabel = template.isWhitelist ? 'Whitelist' : 'Blacklist';
    final typeColor =
        template.isWhitelist ? Colors.greenAccent : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              template.isWhitelist ? Icons.check_circle_outline : Icons.block,
              color: typeColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                            color: typeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${template.packages.length} apps',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: Colors.white54, size: 20),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CreateTemplateScreen(existingTemplate: template),
                ),
              );
              ref.invalidate(blockTemplatesProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Colors.redAccent, size: 20),
            onPressed: () => _deleteTemplate(template),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessibilityBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(26),
        border: Border.all(color: Colors.orange, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Service inactiv",
                  style: TextStyle(
                      color: Colors.orange,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  "Activează Accessibility",
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: () async {
              await getIt<RequestAccessibilityUseCase>()();
              await Future.delayed(const Duration(milliseconds: 500));
              await _checkPermissions();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              "Enable",
              style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(26),
        border: Border.all(color: Colors.red, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.block, color: Colors.red, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Overlay lipsă",
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  "Activează 'Display over other apps'",
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: () async {
              await getIt<RequestOverlayPermissionUseCase>()();
              await Future.delayed(const Duration(milliseconds: 500));
              await _checkPermissions();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              "Enable",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
