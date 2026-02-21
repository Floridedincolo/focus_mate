import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_apps/device_apps.dart';
import '../services/accessibility_service.dart';
import '../services/block_app_manager.dart';

class FocusPage extends StatefulWidget {
  const FocusPage({super.key});

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> with WidgetsBindingObserver {

  // --- LISTĂ APLICAȚII BLOCATE ---
  List<String> _blockedApps = []; // Package names
  bool _blockingEnabled = false;

  // --- ACCESSIBILITY SERVICE STATUS ---
  bool _isAccessibilityEnabled = false;
  bool _hasOverlayPermission = false;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); //  Ascultă schimbările de lifecycle
    _loadBlockedApps();
    _checkAccessibilityService(); //  Verifică imediat la pornire
    _checkOverlayPermission(); //  Verifică permisiunea overlay
  }

    @override
    void dispose() {
      WidgetsBinding.instance.removeObserver(this); //  Curăță observer-ul
      super.dispose();
    }

  //  Verifică accessibility când app-ul revine în foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Delay pentru a lăsa sistemul să se stabilizeze după revenirea în foreground
      Future.delayed(const Duration(milliseconds: 1000), () async {
        await _checkAccessibilityService();
        await _checkOverlayPermission();
      });
    }
  }


  //  Verifică dacă Accessibility Service este activ
  Future<void> _checkAccessibilityService() async {
    final enabled = await AccessibilityService.isEnabled();

    if (mounted) {
      setState(() {
        _isAccessibilityEnabled = enabled;
      });

      if (enabled) {
        print(" Accessibility Service este ACTIV și funcțional!");
      } else {
        print("⚠️ Accessibility Service NU este activ!");
      }
    }
  }

  //  Verifică permisiunea overlay
  Future<void> _checkOverlayPermission() async {
    final canDraw = await AccessibilityService.canDrawOverlays();

    if (mounted) {
      setState(() {
        _hasOverlayPermission = canDraw;
      });

      if (canDraw) {
        print(" Overlay permission este ACTIVĂ!");
      } else {
        print("⚠️ Overlay permission NU este activă!");
      }
    }
  }



    // Încarcă lista de aplicații blocate din SharedPreferences
    Future<void> _loadBlockedApps() async {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _blockedApps = prefs.getStringList('focus_blocked_apps') ?? [];
        _blockingEnabled = prefs.getBool('focus_blocking_enabled') ?? true; //  Default true
      });

      //  Aplică blocarea imediat după încărcare
      if (_blockingEnabled && _blockedApps.isNotEmpty) {
        await BlockAppManager.setBlockedApps(_blockedApps);
        print("🔒 Loaded and applied ${_blockedApps.length} blocked apps");
      }
    }

    // Salvează lista de aplicații blocate
    Future<void> _saveBlockedApps() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('focus_blocked_apps', _blockedApps);
      await prefs.setBool('focus_blocking_enabled', _blockingEnabled);

      //  IMPORTANT: Trimite lista actualizată către serviciul nativ
      await BlockAppManager.setBlockedApps(_blockedApps);
      print(" Saved ${_blockedApps.length} blocked apps to native service");
    }

    // Activează blocarea REALĂ prin block_app
    Future<void> _applyBlocking() async {
      if (_blockingEnabled && _blockedApps.isNotEmpty) {
        // Trimite întreaga listă actualizată
        await BlockAppManager.setBlockedApps(_blockedApps);
        print("🔒 Blocking enabled for ${_blockedApps.length} apps");
      } else {
        await BlockAppManager.clearBlockList();
        print("🔓 Blocking disabled");
      }
    }


    // DIALOG PENTRU SELECTARE APLICAȚII
    void _showAppSelector() async {
      if (!mounted) return;

      // Încarcă lista de aplicații
      List<Application> apps = await DeviceApps.getInstalledApplications(
        includeAppIcons: true,
        includeSystemApps: true,
        onlyAppsWithLaunchIntent: true,
      );

      // Sortează alfabetic
      apps.sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));

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
                      itemCount: apps.length,
                      itemBuilder: (context, index) {
                        final app = apps[index];
                        final isBlocked = _blockedApps.contains(app.packageName);

                        return ListTile(
                          leading: app is ApplicationWithIcon
                              ? Image.memory(app.icon, width: 40, height: 40)
                              : const Icon(Icons.android, color: Colors.white),
                          title: Text(
                            app.appName,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            app.packageName,
                            style: TextStyle(color: Colors.grey[500], fontSize: 11),
                          ),
                          trailing: Checkbox(
                            value: isBlocked,
                            activeColor: Colors.redAccent,
                            onChanged: (val) async {
                              setModalState(() {
                                if (val == true) {
                                  if (!_blockedApps.contains(app.packageName)) {
                                    _blockedApps.add(app.packageName);
                                  }
                                } else {
                                  _blockedApps.remove(app.packageName);
                                }
                              });
                              setState(() {});
                              await _saveBlockedApps();
                              //  Aplică blocarea imediat
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
                // --- TITLU ---
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
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),

                const SizedBox(height: 20),

                //  BANNER ACCESSIBILITY SERVICE (compact)
                if (!_isAccessibilityEnabled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(26),
                      border: Border.all(color: Colors.orange, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
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
                                  fontWeight: FontWeight.bold,
                                ),
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
                            await AccessibilityService.promptEnable();
                            // După ce userul revine din setări, verifică din nou
                            await Future.delayed(const Duration(milliseconds: 500));
                            await _checkAccessibilityService();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text("Enable", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),

                //  BANNER OVERLAY PERMISSION (compact)
                if (!_hasOverlayPermission)
                  Container(
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
                                  fontWeight: FontWeight.bold,
                                ),
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
                            await AccessibilityService.requestOverlayPermission();
                            // După ce userul revine din setări, verifică din nou
                            await Future.delayed(const Duration(milliseconds: 500));
                            await _checkOverlayPermission();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text("Enable", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // --- LISTA APLICAȚII BLOCATE (REAL) ---
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
                          child: const Icon(Icons.block, color: Colors.redAccent),
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
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _blockedApps.isEmpty
                                    ? "Tap to select apps"
                                    : "${_blockedApps.length} apps selected",
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _blockingEnabled,
                          onChanged: (val) async {
                            setState(() {
                              _blockingEnabled = val;
                            });
                            await _saveBlockedApps();
                            //  Aplică blocarea imediat când se schimbă switch-ul
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
