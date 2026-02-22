import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/service_locator.dart';
import '../../domain/entities/blocked_app.dart';
import '../../domain/entities/installed_application.dart';
import '../../domain/usecases/accessibility_usecases.dart';
import '../../domain/usecases/app_usecases.dart';

class FocusPage extends ConsumerStatefulWidget {
  const FocusPage({super.key});

  @override
  ConsumerState<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends ConsumerState<FocusPage>
    with WidgetsBindingObserver {
  List<BlockedApp> _blockedApps = [];
  bool _blockingEnabled = false;

  bool _isAccessibilityEnabled = false;
  bool _hasOverlayPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBlockedApps();
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

  Future<void> _loadBlockedApps() async {
    final blockedApps = await getIt<GetBlockedAppsUseCase>()();

    setState(() {
      _blockedApps = blockedApps;
      _blockingEnabled = _blockedApps.isNotEmpty;
    });
  }

  Future<void> _applyBlocking() async {
    if (_blockingEnabled && _blockedApps.isNotEmpty) {
      await getIt<SetBlockedAppsUseCase>()(_blockedApps);
    } else {
      await getIt<SetBlockedAppsUseCase>()([]);
    }
  }

  void _showAppSelector() async {
    if (!mounted) return;

    List<InstalledApplication> apps =
        await getIt<GetAllAppsUseCase>()();
    apps.sort((a, b) =>
        a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));

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
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
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
                    itemCount: apps.length,
                    itemBuilder: (context, index) {
                      final app = apps[index];
                      final isBlocked = _blockedApps.any(
                          (b) => b.packageName == app.packageName);

                      return ListTile(
                        leading: app.iconBytes != null
                            ? Image.memory(
                                Uint8List.fromList(app.iconBytes!),
                                width: 40,
                                height: 40,
                              )
                            : const Icon(Icons.android,
                                color: Colors.white),
                        title: Text(
                          app.appName,
                          style:
                              const TextStyle(color: Colors.white),
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
                          onChanged: (val) async {
                            setModalState(() {
                              if (val == true) {
                                if (!_blockedApps.any((b) =>
                                    b.packageName ==
                                    app.packageName)) {
                                  _blockedApps.add(BlockedApp(
                                    packageName: app.packageName,
                                    appName: app.appName,
                                  ));
                                }
                              } else {
                                _blockedApps.removeWhere((b) =>
                                    b.packageName ==
                                    app.packageName);
                              }
                            });
                            setState(() {});
                            if (_blockingEnabled) {
                              await _applyBlocking();
                            }
                          },
                        ),
                      );
                    },
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
    final bgColor = const Color(0xFF0D0D0D);
    final cardColor = const Color(0xFF1E1E1E);
    final accentColor = Colors.blueAccent;

    return Scaffold(
      backgroundColor: bgColor,
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
                  "Stay productive, silence distractions.",
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
                const SizedBox(height: 20),

                // Accessibility banner
                if (!_isAccessibilityEnabled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(26),
                      border: Border.all(
                          color: Colors.orange, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                            size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
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
                                style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          onPressed: () async {
                            await getIt<
                                RequestAccessibilityUseCase>()();
                            await Future.delayed(
                                const Duration(milliseconds: 500));
                            await _checkPermissions();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(8)),
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
                  ),

                // Overlay banner
                if (!_hasOverlayPermission)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(26),
                      border:
                          Border.all(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.block,
                            color: Colors.red, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
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
                                style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          onPressed: () async {
                            await getIt<
                                RequestOverlayPermissionUseCase>()();
                            await Future.delayed(
                                const Duration(milliseconds: 500));
                            await _checkPermissions();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(8)),
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
                  ),

                const SizedBox(height: 20),

                // Blocked apps card
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
                          child: const Icon(Icons.block,
                              color: Colors.redAccent),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Blocked Apps",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _blockedApps.isEmpty
                                    ? "Tap to select apps"
                                    : "${_blockedApps.length} apps selected",
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _blockingEnabled,
                          onChanged: (val) async {
                            setState(() =>
                                _blockingEnabled = val);
                            await _applyBlocking();
                          },
                          activeColor: accentColor,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

