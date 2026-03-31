import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/service_locator.dart';
import '../../domain/entities/app_block_template.dart';
import '../../domain/entities/installed_application.dart';
import '../../domain/repositories/block_template_repository.dart';
import '../../domain/usecases/app_usecases.dart';
import '../providers/block_template_providers.dart';

class CreateTemplateScreen extends ConsumerStatefulWidget {
  final AppBlockTemplate? existingTemplate;

  const CreateTemplateScreen({super.key, this.existingTemplate});

  @override
  ConsumerState<CreateTemplateScreen> createState() =>
      _CreateTemplateScreenState();
}

class _CreateTemplateScreenState extends ConsumerState<CreateTemplateScreen> {
  late final TextEditingController _nameController;
  bool _isWhitelist = false;
  Set<String> _selectedPackages = {};
  List<InstalledApplication> _apps = [];
  bool _loadingApps = true;
  String _searchQuery = '';

  bool get _isEditing => widget.existingTemplate != null;

  @override
  void initState() {
    super.initState();
    final t = widget.existingTemplate;
    _nameController = TextEditingController(text: t?.name ?? '');
    _isWhitelist = t?.isWhitelist ?? false;
    _selectedPackages = Set.from(t?.packages ?? []);
    _loadApps();
  }

  @override
  void dispose() {
    _nameController.dispose();
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
      packages: _selectedPackages.toList(),
    );

    await getIt<BlockTemplateRepository>().saveTemplate(template);
    ref.invalidate(blockTemplatesProvider);

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
    final filteredApps = _searchQuery.isEmpty
        ? _apps
        : _apps
            .where((a) =>
                a.appName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                a.packageName
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()))
            .toList();

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
                    prefixIcon:
                        const Icon(Icons.label_outline, color: Colors.white38),
                    filled: true,
                    fillColor: _card,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.06))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: _accent, width: 1.5)),
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
                  child: Row(children: [
                    _typeToggle(
                        label: 'Blacklist',
                        icon: Icons.block,
                        selected: !_isWhitelist,
                        color: Colors.redAccent,
                        onTap: () => setState(() => _isWhitelist = false)),
                    _typeToggle(
                        label: 'Whitelist',
                        icon: Icons.check_circle_outline,
                        selected: _isWhitelist,
                        color: Colors.greenAccent,
                        onTap: () => setState(() => _isWhitelist = true)),
                  ]),
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
                const Text('APPS',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8)),
                const SizedBox(height: 8),
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
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 4),
                Text('${_selectedPackages.length} selected',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loadingApps
                ? const Center(
                    child:
                        CircularProgressIndicator(color: Colors.blueAccent))
                : ListView.builder(
                    itemCount: filteredApps.length,
                    itemBuilder: (context, index) {
                      final app = filteredApps[index];
                      final isSelected =
                          _selectedPackages.contains(app.packageName);
                      return ListTile(
                        leading: app.iconBytes != null
                            ? Image.memory(
                                Uint8List.fromList(app.iconBytes!),
                                width: 36,
                                height: 36)
                            : const Icon(Icons.android,
                                color: Colors.white, size: 36),
                        title: Text(app.appName,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14)),
                        subtitle: Text(app.packageName,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 11)),
                        trailing: Checkbox(
                          value: isSelected,
                          activeColor: _isWhitelist
                              ? Colors.greenAccent
                              : Colors.redAccent,
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
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedPackages.remove(app.packageName);
                            } else {
                              _selectedPackages.add(app.packageName);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
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
            child: Text(_isEditing ? 'Save Changes' : 'Create Template',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600)),
          ),
        ),
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
            color:
                selected ? color.withValues(alpha: 0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: color.withValues(alpha: 0.5))
                : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: selected ? color : Colors.white54, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: selected ? color : Colors.white54,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 15)),
          ]),
        ),
      ),
    );
  }
}
