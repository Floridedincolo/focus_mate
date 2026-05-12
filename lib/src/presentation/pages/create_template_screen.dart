import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/service_locator.dart';
import '../../domain/entities/app_block_template.dart';
import '../../domain/entities/installed_application.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/block_template_repository.dart';
import '../../domain/usecases/app_usecases.dart';
import '../providers/block_template_providers.dart';
import '../providers/task_providers.dart';

class CreateTemplateScreen extends ConsumerStatefulWidget {
  final AppBlockTemplate? existingTemplate;

  const CreateTemplateScreen({super.key, this.existingTemplate});

  @override
  ConsumerState<CreateTemplateScreen> createState() =>
      _CreateTemplateScreenState();
}

class _CreateTemplateScreenState extends ConsumerState<CreateTemplateScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _nameController;
  late final TextEditingController _websiteController;
  late final TextEditingController _keywordController;
  late final TabController _tabController;

  bool _isWhitelist = false;
  String _mode = 'hard';
  Set<String> _selectedPackages = {};
  Set<String> _blockedWebsites = {};
  Set<String> _blockedKeywords = {};
  // package -> set of enabled in-app feature flags
  Map<String, Set<String>> _inAppBlocks = {};
  // packages whose in-app block panel is currently expanded in the UI
  final Set<String> _expandedInApp = {};
  List<InstalledApplication> _apps = [];
  bool _loadingApps = true;
  String _searchQuery = '';

  // Catalog of supported in-app feature blocks per package.
  // Add more entries here to support additional apps.
  static const Map<String, List<_InAppFeature>> _inAppCatalog = {
    'com.google.android.youtube': [
      _InAppFeature('shorts', 'Block shorts', Icons.videocam_outlined),
      _InAppFeature('video_search', 'Block video search', Icons.search),
      _InAppFeature('pip', 'Block picture-in-picture mode',
          Icons.picture_in_picture_alt_outlined),
      _InAppFeature('comments', 'Block comments', Icons.chat_bubble_outline),
    ],
    'com.instagram.android': [
      _InAppFeature('stories', 'Block stories', Icons.circle_outlined),
      _InAppFeature('reels', 'Block reels', Icons.movie_creation_outlined),
      _InAppFeature('explore', 'Block explore tab', Icons.search),
    ],
    'com.facebook.katana': [
      _InAppFeature('reels', 'Block reels', Icons.movie_creation_outlined),
      _InAppFeature('stories', 'Block stories', Icons.circle_outlined),
    ],
    'com.snapchat.android': [
      _InAppFeature('spotlight', 'Block spotlight', Icons.movie_creation_outlined),
      _InAppFeature('stories', 'Block stories', Icons.circle_outlined),
    ],
    'com.zhiliaoapp.musically': [
      _InAppFeature('fyp', 'Block For You page', Icons.movie_creation_outlined),
      _InAppFeature('search', 'Block search', Icons.search),
    ],
  };

  bool get _isEditing => widget.existingTemplate != null;

  @override
  void initState() {
    super.initState();
    final t = widget.existingTemplate;
    _nameController = TextEditingController(text: t?.name ?? '');
    _websiteController = TextEditingController();
    _keywordController = TextEditingController();
    _tabController = TabController(length: 3, vsync: this);
    _isWhitelist = t?.isWhitelist ?? false;
    _mode = t?.mode ?? 'hard';
    _selectedPackages = Set.from(t?.packages ?? []);
    _blockedWebsites = Set.from(t?.blockedWebsites ?? []);
    _blockedKeywords = Set.from(t?.blockedKeywords ?? []);
    _inAppBlocks = {
      for (final e in (t?.inAppBlocks ?? const <String, List<String>>{}).entries)
        e.key: Set<String>.from(e.value),
    };
    _loadApps();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _websiteController.dispose();
    _keywordController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    final apps = await getIt<GetUserAppsUseCase>()();
    apps.sort(
        (a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));
    if (mounted) {
      setState(() {
        _apps = apps;
        _loadingApps = false;
      });
    }
  }

  void _addWebsite() {
    final site = _websiteController.text.trim().toLowerCase();
    if (site.isEmpty) return;
    // Strip protocol if user pastes full URL
    final cleaned = site
        .replaceAll(RegExp(r'^https?://'), '')
        .replaceAll(RegExp(r'^www\.'), '')
        .replaceAll(RegExp(r'/.*$'), '');
    if (cleaned.isNotEmpty) {
      setState(() => _blockedWebsites.add(cleaned));
      _websiteController.clear();
    }
  }

  void _addKeyword() {
    final keyword = _keywordController.text.trim().toLowerCase();
    if (keyword.isEmpty) return;
    setState(() => _blockedKeywords.add(keyword));
    _keywordController.clear();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Template name is required'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }

    final template = AppBlockTemplate(
      id: widget.existingTemplate?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      isWhitelist: _isWhitelist,
      mode: _mode,
      packages: _selectedPackages.toList(),
      blockedWebsites: _blockedWebsites.toList(),
      blockedKeywords: _blockedKeywords.toList(),
      inAppBlocks: {
        for (final e in _inAppBlocks.entries)
          if (e.value.isNotEmpty) e.key: e.value.toList(),
      },
    );

    await getIt<BlockTemplateRepository>().saveTemplate(template);
    ref.invalidate(blockTemplatesProvider);

    // Force schedule.json to be rewritten immediately so the native
    // accessibility service sees the new mode/isWhitelist/packages
    // without depending on Home's listener being mounted.
    try {
      final freshTemplates =
          await ref.read(blockTemplatesProvider.future);
      final List<Task> tasks =
          ref.read(tasksStreamProvider).valueOrNull ?? const [];
      await syncFocusScheduleToNative(tasks, freshTemplates);
    } catch (_) {
      // Best-effort; the Home listener will still try to sync later.
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(_isEditing ? 'Template updated!' : 'Template created!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  static const _bg = Color(0xFF0D0D0D);
  static const _card = Color(0xFF1A1A1A);
  static const _accent = Colors.blueAccent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Template' : 'New Template',
          style: const TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Name + Type settings
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NAME',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. Study Mode, Work Focus...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.label_outline,
                        color: Colors.white38),
                    filled: true,
                    fillColor: _card,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _accent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text('TYPE',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                      color: _card, borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _typeToggle(
                        label: 'Blacklist',
                        icon: Icons.block,
                        selected: !_isWhitelist,
                        color: Colors.redAccent,
                        onTap: () => setState(() => _isWhitelist = false),
                      ),
                      _typeToggle(
                        label: 'Whitelist',
                        icon: Icons.check_circle_outline,
                        selected: _isWhitelist,
                        color: Colors.greenAccent,
                        onTap: () => setState(() => _isWhitelist = true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    _isWhitelist
                        ? 'Only selected apps will be ALLOWED. Everything else is blocked.'
                        : 'Selected apps will be BLOCKED. Everything else is allowed.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),

                const Text('MODE',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                      color: _card, borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _typeToggle(
                        label: 'Light',
                        icon: Icons.notifications_active_outlined,
                        selected: _mode == 'light',
                        color: Colors.amberAccent,
                        onTap: () => setState(() => _mode = 'light'),
                      ),
                      _typeToggle(
                        label: 'Hard',
                        icon: Icons.lock,
                        selected: _mode == 'hard',
                        color: Colors.redAccent,
                        onTap: () => setState(() => _mode = 'hard'),
                      ),
                      _typeToggle(
                        label: 'Lockdown',
                        icon: Icons.shield_outlined,
                        selected: _mode == 'lockdown',
                        color: Colors.greenAccent,
                        onTap: () => setState(() => _mode = 'lockdown'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    _mode == 'hard'
                        ? 'Re-blocks the app every time you reopen it.'
                        : _mode == 'light'
                            ? 'Shows a warning, then gives you 30s on the app before blocking again.'
                            : 'Fullscreen takeover with the task name and a countdown — no way out until the session ends.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // Tab bar + content (hidden entirely in Lockdown — the mode is
          // device-wide and the apps/webs/keywords lists have no effect).
          if (_mode == 'lockdown')
            Expanded(child: _buildLockdownPlaceholder())
          else ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: _accent.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _accent.withValues(alpha: 0.5)),
                ),
                dividerColor: Colors.transparent,
                labelColor: _accent,
                unselectedLabelColor: Colors.white54,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                unselectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
                tabs: [
                  _tabLabel('Apps', _selectedPackages.length),
                  _tabLabel('Webs', _blockedWebsites.length),
                  _tabLabel('Keywords', _blockedKeywords.length),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAppsTab(),
                  _buildWebsitesTab(),
                  _buildKeywordsTab(),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              _isEditing ? 'Save Changes' : 'Create Template',
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockdownPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined,
                color: Colors.greenAccent.withValues(alpha: 0.7), size: 64),
            const SizedBox(height: 16),
            const Text(
              'Lockdown is device-wide',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Nothing to pick — the whole device is locked for the entire session. Only the phone dialer is allowed through.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabLabel(String label, int count) {
    return Tab(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (count > 0) ...[
              const SizedBox(width: 4),
              _badge(count),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
    );
  }

  // ── Apps Tab ──

  Widget _buildAppsTab() {
    final filteredApps = _searchQuery.isEmpty
        ? _apps
        : _apps
            .where((a) =>
                a.appName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                a.packageName
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                style: const TextStyle(color: Colors.white),
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search apps...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.white38),
                  filled: true,
                  fillColor: _card,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_selectedPackages.length} selected',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _loadingApps
              ? const Center(
                  child:
                      CircularProgressIndicator(color: Colors.blueAccent))
              : ListView.builder(
                  itemCount: filteredApps.length,
                  itemBuilder: (context, index) {
                    final app = filteredApps[index];
                    return _buildAppRow(app);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAppRow(InstalledApplication app) {
    final isSelected = _selectedPackages.contains(app.packageName);
    final features = _inAppCatalog[app.packageName];
    final hasInApp = features != null && features.isNotEmpty;
    final isExpanded = _expandedInApp.contains(app.packageName);
    final enabledFeatures =
        _inAppBlocks[app.packageName] ?? const <String>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: app.iconBytes != null
              ? Image.memory(
                  Uint8List.fromList(app.iconBytes!),
                  width: 36,
                  height: 36,
                )
              : const Icon(Icons.android, color: Colors.white, size: 36),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  app.appName,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              if (hasInApp && enabledFeatures.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${enabledFeatures.length}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            app.packageName,
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasInApp)
                IconButton(
                  icon: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white54,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedInApp.remove(app.packageName);
                      } else {
                        _expandedInApp.add(app.packageName);
                      }
                    });
                  },
                ),
              Checkbox(
                value: isSelected,
                activeColor:
                    _isWhitelist ? Colors.greenAccent : Colors.redAccent,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedPackages.add(app.packageName);
                    } else {
                      _selectedPackages.remove(app.packageName);
                    }
                  });
                },
              ),
            ],
          ),
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedPackages.remove(app.packageName);
              } else {
                _selectedPackages.add(app.packageName);
              }
            });
          },
        ),
        if (hasInApp && isExpanded)
          _buildInAppPanel(app.packageName, features),
      ],
    );
  }

  Widget _buildInAppPanel(String pkg, List<_InAppFeature> features) {
    final enabled = _inAppBlocks.putIfAbsent(pkg, () => <String>{});
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (final f in features)
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: _accent,
              value: enabled.contains(f.id),
              onChanged: (v) {
                setState(() {
                  if (v) {
                    enabled.add(f.id);
                  } else {
                    enabled.remove(f.id);
                  }
                });
              },
              title: Row(
                children: [
                  Icon(f.icon, color: Colors.white70, size: 20),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      f.label,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Websites Tab ──

  Widget _buildWebsitesTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _websiteController,
                  style: const TextStyle(color: Colors.white),
                  onFieldSubmitted: (_) => _addWebsite(),
                  decoration: InputDecoration(
                    hintText: 'Add website (e.g. youtube.com)',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon:
                        const Icon(Icons.language, color: Colors.white38),
                    filled: true,
                    fillColor: _card,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addWebsite,
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: _accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_blockedWebsites.length} website${_blockedWebsites.length == 1 ? '' : 's'} blocked',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _blockedWebsites.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.language,
                            color: Colors.grey[700], size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'No websites blocked yet',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add websites above to block them during focus sessions',
                          style: TextStyle(
                              color: Colors.grey[700], fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _blockedWebsites.length,
                    itemBuilder: (context, index) {
                      final site = _blockedWebsites.elementAt(index);
                      return ListTile(
                        leading: const Icon(Icons.language,
                            color: Colors.blueAccent, size: 28),
                        title: Text(
                          site,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white38, size: 20),
                          onPressed: () =>
                              setState(() => _blockedWebsites.remove(site)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Keywords Tab ──

  Widget _buildKeywordsTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _keywordController,
                  style: const TextStyle(color: Colors.white),
                  onFieldSubmitted: (_) => _addKeyword(),
                  decoration: InputDecoration(
                    hintText: 'Add keyword (e.g. tiktok)',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.text_fields,
                        color: Colors.white38),
                    filled: true,
                    fillColor: _card,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addKeyword,
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: _accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_blockedKeywords.length} keyword${_blockedKeywords.length == 1 ? '' : 's'} blocked',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'URLs containing these keywords will be blocked',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _blockedKeywords.isEmpty
                ? SingleChildScrollView(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.text_fields,
                                color: Colors.grey[700], size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'No keywords blocked yet',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add keywords to block any URL that contains them',
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _blockedKeywords.length,
                    itemBuilder: (context, index) {
                      final keyword = _blockedKeywords.elementAt(index);
                      return ListTile(
                        leading: const Icon(Icons.text_fields,
                            color: Colors.orangeAccent, size: 28),
                        title: Text(
                          keyword,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white38, size: 20),
                          onPressed: () => setState(
                              () => _blockedKeywords.remove(keyword)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _typeToggle({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: color.withValues(alpha: 0.5))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? color : Colors.white54, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                    color: selected ? color : Colors.white54,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InAppFeature {
  final String id;
  final String label;
  final IconData icon;
  const _InAppFeature(this.id, this.label, this.icon);
}
