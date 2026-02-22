import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/blocked_app.dart';
import '../providers/app_providers.dart';
import '../providers/accessibility_providers.dart';

class FocusPage extends ConsumerStatefulWidget {
  const FocusPage({super.key});

  @override
  ConsumerState<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends ConsumerState<FocusPage>
    with WidgetsBindingObserver {
  List<String> _blockedApps = [];
  bool _blockingEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBlockedApps();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh accessibility status when app resumes
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          ref.refresh(checkAccessibilityProvider);
          ref.refresh(checkOverlayPermissionProvider);
        }
      });
    }
  }

  Future<void> _loadBlockedApps() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _blockedApps = prefs.getStringList('focus_blocked_apps') ?? [];
      _blockingEnabled = prefs.getBool('focus_blocking_enabled') ?? true;
    });
  }

  Future<void> _saveBlockedApps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('focus_blocked_apps', _blockedApps);
    await prefs.setBool('focus_blocking_enabled', _blockingEnabled);

    // Update through use case
    final apps = _blockedApps
        .map(
          (packageName) => BlockedApp(
            packageName: packageName,
            appName: packageName,
          ),
        )
        .toList();

    if (mounted) {
      ref.read(setBlockedAppsProvider(apps));
    }
  }

  void _showAppSelector() async {
    if (!mounted) return;

    // Load apps through Riverpod provider
    final userApps = await ref.read(userAppsProvider.future);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "Select Apps to Block",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: userApps.length,
                    itemBuilder: (context, index) {
                      final app = userApps[index];
                      final isBlocked = _blockedApps.contains(app.packageName);

                      return ListTile(
                        leading: app.iconBytes != null
                            ? Image.memory(
                                app.iconBytes! as dynamic,
                                width: 40,
                                height: 40,
                              )
                            : const Icon(
                                Icons.android,
                                color: Colors.white,
                              ),
                        title: Text(
                          app.appName,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          app.packageName,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                        trailing: Checkbox(
                          value: isBlocked,
                          activeColor: Colors.redAccent,
                          onChanged: (value) {
                            setModalState(() {
                              if (value == true) {
                                _blockedApps.add(app.packageName);
                              } else {
                                _blockedApps.remove(app.packageName);
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: () async {
                      await _saveBlockedApps();
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text(
                      "Apply",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch accessibility status
    final accessibilityStatus = ref.watch(checkAccessibilityProvider);
    final overlayPermission = ref.watch(checkOverlayPermissionProvider);
    final blockedAppsStream = ref.watch(blockedAppsStreamProvider);

    const cardColor = Color(0xFF1A1A1A);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text(
          'Focus Mode',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Accessibility Status
            accessibilityStatus.when(
              data: (isEnabled) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isEnabled ? Colors.green.withAlpha(26) : Colors.red.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isEnabled ? Colors.green : Colors.red,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isEnabled ? Icons.check_circle : Icons.warning,
                      color: isEnabled ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEnabled
                                ? '✅ Accessibility Enabled'
                                : '⚠️ Accessibility Disabled',
                            style: TextStyle(
                              color: isEnabled ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            isEnabled
                                ? 'Ready to block apps'
                                : 'Enable in Settings',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isEnabled)
                      ElevatedButton(
                        onPressed: () {
                          ref.read(requestAccessibilityProvider);
                        },
                        child: const Text('Enable'),
                      ),
                  ],
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Error: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Overlay Permission
            overlayPermission.when(
              data: (hasPermission) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: hasPermission
                      ? Colors.blue.withAlpha(26)
                      : Colors.orange.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasPermission ? Icons.layers : Icons.layers_outlined,
                      color: hasPermission ? Colors.blue : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hasPermission
                            ? '✅ Overlay Permission Granted'
                            : '⚠️ Overlay Permission Required',
                        style: TextStyle(
                          color: hasPermission ? Colors.blue : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (error, stack) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),

            // Blocked Apps List
            const Text(
              'Blocked Apps',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _showAppSelector,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.block,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Blocked Apps",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _blockedApps.isEmpty
                                ? 'Add apps to block'
                                : '${_blockedApps.length} apps blocked',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.grey, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_blockedApps.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Currently Blocked:',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _blockedApps
                          .map(
                            (app) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withAlpha(51),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                app,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

