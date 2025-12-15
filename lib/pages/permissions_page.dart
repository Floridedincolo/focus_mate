import 'package:flutter/material.dart';
import 'package:focus_mate/services/app_blocker_service.dart';

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  final _blockerService = AppBlockerService();
  bool _hasOverlay = false;
  bool _hasUsageStats = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);
    try {
      final hasOverlay = await _blockerService.hasOverlayPermission();
      final hasUsage = await _blockerService.hasUsageStatsPermission();
      setState(() {
        _hasOverlay = hasOverlay;
        _hasUsageStats = hasUsage;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking permissions: $e')),
        );
      }
    }
  }

  Future<void> _requestOverlayPermission() async {
    try {
      await _blockerService.requestOverlayPermission();
      // Show instructions
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable "Display over other apps" permission in the settings that just opened.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
      // Wait a bit for user to potentially grant permission
      await Future.delayed(const Duration(seconds: 2));
      _checkPermissions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error requesting permission: $e')),
        );
      }
    }
  }

  Future<void> _requestUsageStatsPermission() async {
    try {
      await _blockerService.requestUsageStatsPermission();
      // Show instructions
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable "Usage access" permission in the settings that just opened.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
      // Wait a bit for user to potentially grant permission
      await Future.delayed(const Duration(seconds: 2));
      _checkPermissions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error requesting permission: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Blocking Permissions'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _checkPermissions,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Required Permissions',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'FocusMate needs these permissions to block distracting apps during focus sessions.',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          _buildPermissionTile(
                            title: 'Display Over Other Apps',
                            description: 'Allows FocusMate to show a blocking screen over apps',
                            isGranted: _hasOverlay,
                            onRequest: _requestOverlayPermission,
                          ),
                          const Divider(),
                          _buildPermissionTile(
                            title: 'Usage Access',
                            description: 'Allows FocusMate to detect when blocked apps are opened',
                            isGranted: _hasUsageStats,
                            onRequest: _requestUsageStatsPermission,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_hasOverlay && _hasUsageStats)
                    Card(
                      color: Colors.green.shade50,
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'All permissions granted! You can now use app blocking features.',
                                style: TextStyle(color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How It Works',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            icon: Icons.block,
                            text: 'When you start a task, selected apps will be blocked',
                          ),
                          _buildInfoRow(
                            icon: Icons.phone_android,
                            text: 'If you try to open a blocked app, you\'ll see a blocking screen',
                          ),
                          _buildInfoRow(
                            icon: Icons.timer,
                            text: 'Apps are automatically unblocked when your task ends',
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

  Widget _buildPermissionTile({
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onRequest,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isGranted ? Icons.check_circle : Icons.cancel,
        color: isGranted ? Colors.green : Colors.red,
        size: 32,
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(description),
      trailing: isGranted
          ? null
          : ElevatedButton(
              onPressed: onRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
              child: const Text('Grant', style: TextStyle(color: Colors.white)),
            ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.deepPurple),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

