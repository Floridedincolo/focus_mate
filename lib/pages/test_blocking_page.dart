import 'package:flutter/material.dart';
import 'package:focus_mate/services/app_blocker_service.dart';

class TestBlockingPage extends StatefulWidget {
  const TestBlockingPage({super.key});

  @override
  State<TestBlockingPage> createState() => _TestBlockingPageState();
}

class _TestBlockingPageState extends State<TestBlockingPage> {
  final _blockerService = AppBlockerService();
  bool _isLoading = false;
  String _status = 'Ready to test';
  List<String> _blockedApps = [];

  @override
  void initState() {
    super.initState();
    _loadBlockedApps();
  }

  Future<void> _loadBlockedApps() async {
    final blocked = await _blockerService.getBlockedApps();
    setState(() {
      _blockedApps = blocked;
    });
  }

  Future<void> _testBlockYouTube() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing YouTube blocking...';
    });

    try {
      // Check permissions first
      final hasOverlay = await _blockerService.hasOverlayPermission();
      final hasUsage = await _blockerService.hasUsageStatsPermission();

      debugPrint('📋 Overlay permission: $hasOverlay');
      debugPrint('📋 Usage Stats permission: $hasUsage');

      if (!hasOverlay || !hasUsage) {
        setState(() {
          _status = '❌ Missing permissions! Go to Permissions page first.';
          _isLoading = false;
        });
        return;
      }

      // Block YouTube
      debugPrint('🚀 Attempting to block YouTube...');
      final success = await _blockerService.blockApp('com.google.android.youtube');
      debugPrint('✅ Block result: $success');

      if (success) {
        // Get blocked apps to verify
        final blockedApps = await _blockerService.getBlockedApps();
        debugPrint('📱 Currently blocked apps: $blockedApps');

        // Start the blocking service
        debugPrint('🔧 Starting blocking service...');
        final serviceStarted = await _blockerService.startBlockingService();
        debugPrint('✅ Service started: $serviceStarted');

        setState(() {
          _blockedApps = blockedApps;
          _status = serviceStarted
              ? '✅ YouTube is now blocked! Try opening YouTube app.'
              : '⚠️ YouTube blocked but service failed to start';
          _isLoading = false;
        });
      } else {
        setState(() {
          _status = '❌ Failed to block YouTube';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      setState(() {
        _status = '❌ Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _unblockAll() async {
    setState(() {
      _isLoading = true;
      _status = 'Unblocking all apps...';
    });

    try {
      await _blockerService.unblockAllApps();
      await _blockerService.stopBlockingService();
      await _loadBlockedApps();

      setState(() {
        _status = '✅ All apps unblocked';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test App Blocking'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      _status.startsWith('✅') ? Icons.check_circle : Icons.info,
                      size: 48,
                      color: _status.startsWith('✅') ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_blockedApps.isNotEmpty) ...[
              const Text(
                'Currently Blocked Apps:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _blockedApps.map((app) =>
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text('• $app'),
                      )
                    ).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testBlockYouTube,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.block),
              label: const Text('Block YouTube & Test'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _unblockAll,
              icon: const Icon(Icons.lock_open),
              label: const Text('Unblock All Apps'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),
            const Card(
              color: Colors.blue,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to test:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Make sure permissions are granted\n'
                      '2. Click "Block YouTube & Test"\n'
                      '3. Wait for success message\n'
                      '4. Press Home button\n'
                      '5. Try to open YouTube app\n'
                      '6. You should see a blocking overlay',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

