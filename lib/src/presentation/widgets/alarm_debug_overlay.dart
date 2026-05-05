import 'package:flutter/material.dart';

/// Global in-memory log buffer for alarm debugging.
/// Visible on-device without logcat.
class AlarmDebugLog {
  AlarmDebugLog._();

  static final List<String> _logs = [];
  static final ValueNotifier<int> onChange = ValueNotifier(0);

  static void log(String message) {
    final ts = DateTime.now().toString().substring(11, 19); // HH:mm:ss
    _logs.add('[$ts] $message');
    if (_logs.length > 200) _logs.removeAt(0);
    onChange.value++;
  }

  static List<String> get logs => List.unmodifiable(_logs);

  static void clear() {
    _logs.clear();
    onChange.value++;
  }
}

/// Draggable floating button that opens the alarm debug log overlay.
class AlarmDebugOverlay extends StatefulWidget {
  final Widget child;
  const AlarmDebugOverlay({super.key, required this.child});

  @override
  State<AlarmDebugOverlay> createState() => _AlarmDebugOverlayState();
}

class _AlarmDebugOverlayState extends State<AlarmDebugOverlay> {
  bool _showLog = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Floating debug button
        Positioned(
          right: 8,
          top: MediaQuery.of(context).padding.top + 4,
          child: GestureDetector(
            onTap: () => setState(() => _showLog = !_showLog),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _showLog ? Colors.red : Colors.orange.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _showLog ? Icons.close : Icons.bug_report,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
        // Log panel
        if (_showLog)
          Positioned(
            top: MediaQuery.of(context).padding.top + 44,
            left: 8,
            right: 8,
            bottom: 100,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.92),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange, width: 1),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        const Text('ALARM DEBUG LOG',
                            style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            AlarmDebugLog.clear();
                            setState(() {});
                          },
                          child: const Text('CLEAR',
                              style: TextStyle(
                                  color: Colors.red, fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.orange, height: 1),
                  Expanded(
                    child: ValueListenableBuilder<int>(
                      valueListenable: AlarmDebugLog.onChange,
                      builder: (_, __, ___) {
                        final logs = AlarmDebugLog.logs;
                        return ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.all(6),
                          itemCount: logs.length,
                          itemBuilder: (_, i) {
                            final idx = logs.length - 1 - i;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                logs[idx],
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
