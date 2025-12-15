# 🔌 App Blocker Integration Guide

## Quick Start - Using AppBlockerService

### 1. Import the Service
```dart
import 'package:focus_mate/services/app_blocker_service.dart';
```

### 2. Basic Usage Examples

#### Check Permissions
```dart
final blocker = AppBlockerService();

// Check individual permissions
bool hasOverlay = await blocker.hasOverlayPermission();
bool hasUsage = await blocker.hasUsageStatsPermission();

// Check all at once
bool ready = await blocker.hasAllPermissions();
if (!ready) {
  // Navigate user to permissions page
  Navigator.pushNamed(context, '/permissions');
}
```

#### Block/Unblock Apps
```dart
// Block a single app
await blocker.blockApp('com.google.android.youtube');

// Unblock a single app
await blocker.unblockApp('com.google.android.youtube');

// Block multiple apps
await blocker.blockApps([
  'com.google.android.youtube',
  'com.facebook.katana',
  'com.instagram.android',
]);

// Unblock all apps
await blocker.unblockAllApps();
```

#### Get Installed Apps
```dart
// Get user apps only (default)
List<AppModel> apps = await blocker.getInstalledApps();

// Include system apps
List<AppModel> allApps = await blocker.getInstalledApps(includeSystemApps: true);

// Use app info
for (final app in apps) {
  print('${app.appName}: ${app.packageName}');
}
```

#### Get Blocked Apps
```dart
List<String> blockedPackages = await blocker.getBlockedApps();
print('Currently blocked: $blockedPackages');
```

## Integration with Tasks

### Step 1: Update Task Model

Add `blockedApps` field to Task:

```dart
// lib/models/task.dart
class Task {
  final String id;
  final String title;
  // ...existing fields...
  final List<String> blockedApps; // NEW FIELD

  Task({
    required this.id,
    required this.title,
    // ...existing parameters...
    this.blockedApps = const [], // NEW PARAMETER
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      // ...existing fields...
      'blockedApps': blockedApps, // NEW
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      // ...existing fields...
      blockedApps: List<String>.from(map['blockedApps'] ?? []), // NEW
    );
  }
}
```

### Step 2: Create App Selector Widget

```dart
// lib/widgets/app_selector_dialog.dart
import 'package:flutter/material.dart';
import 'package:focus_mate/services/app_blocker_service.dart';

class AppSelectorDialog extends StatefulWidget {
  final List<String> initiallySelected;
  
  const AppSelectorDialog({
    super.key,
    this.initiallySelected = const [],
  });

  @override
  State<AppSelectorDialog> createState() => _AppSelectorDialogState();
}

class _AppSelectorDialogState extends State<AppSelectorDialog> {
  final _blocker = AppBlockerService();
  List<AppModel> _apps = [];
  Set<String> _selectedPackages = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedPackages = Set.from(widget.initiallySelected);
    _loadApps();
  }

  Future<void> _loadApps() async {
    final apps = await _blocker.getInstalledApps();
    setState(() {
      _apps = apps;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Apps to Block'),
      content: _loading
          ? const Center(child: CircularProgressIndicator())
          : SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                itemCount: _apps.length,
                itemBuilder: (context, index) {
                  final app = _apps[index];
                  final isSelected = _selectedPackages.contains(app.packageName);
                  
                  return CheckboxListTile(
                    value: isSelected,
                    title: Text(app.appName),
                    subtitle: Text(app.packageName, style: const TextStyle(fontSize: 11)),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedPackages.add(app.packageName);
                        } else {
                          _selectedPackages.remove(app.packageName);
                        }
                      });
                    },
                  );
                },
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedPackages.toList()),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
```

### Step 3: Use in Add/Edit Task

```dart
// In lib/pages/add_task.dart or wherever you create/edit tasks

class _AddTaskMenuState extends State<AddTaskMenu> {
  List<String> _selectedBlockedApps = [];

  // Add this method
  Future<void> _selectAppsToBlock() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AppSelectorDialog(
        initiallySelected: _selectedBlockedApps,
      ),
    );
    
    if (result != null) {
      setState(() {
        _selectedBlockedApps = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ...existing UI...
      body: ListView(
        children: [
          // ...existing form fields...
          
          // NEW: Add blocked apps selector
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Blocked Apps'),
            subtitle: Text(
              _selectedBlockedApps.isEmpty
                  ? 'No apps selected'
                  : '${_selectedBlockedApps.length} apps will be blocked',
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: _selectAppsToBlock,
          ),
          
          // ...rest of form...
        ],
      ),
    );
  }

  // When saving task
  Future<void> _saveTask() async {
    final task = Task(
      id: '', // Will be set by Firestore
      title: _titleController.text,
      // ...other fields...
      blockedApps: _selectedBlockedApps, // NEW
    );
    
    await FirestoreService().addTask(task);
    Navigator.pop(context);
  }
}
```

### Step 4: Implement Blocking on Task Start

```dart
// In your task execution logic (e.g., when user taps "Start" on a task)

Future<void> startTask(Task task) async {
  final blocker = AppBlockerService();
  
  // Check if permissions are granted
  final hasPermissions = await blocker.hasAllPermissions();
  if (!hasPermissions) {
    // Show dialog or navigate to permissions page
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text('Please grant app blocking permissions to use this feature.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/permissions');
            },
            child: const Text('Grant Permissions'),
          ),
        ],
      ),
    );
    return;
  }
  
  // Block the apps
  if (task.blockedApps.isNotEmpty) {
    await blocker.blockApps(task.blockedApps);
    print('✅ Blocked ${task.blockedApps.length} apps');
  }
  
  // Start task timer, update UI, etc.
  // ...
}
```

### Step 5: Implement Unblocking on Task End

```dart
// When task completes or is stopped

Future<void> endTask(Task task) async {
  final blocker = AppBlockerService();
  
  // Unblock apps for this task
  for (final packageName in task.blockedApps) {
    await blocker.unblockApp(packageName);
  }
  
  print('✅ Unblocked ${task.blockedApps.length} apps');
  
  // Update task completion, UI, etc.
  // ...
}
```

## Advanced: Task Session Manager

Create a service to manage active task sessions:

```dart
// lib/services/task_session_manager.dart
class TaskSessionManager {
  static final TaskSessionManager _instance = TaskSessionManager._internal();
  factory TaskSessionManager() => _instance;
  TaskSessionManager._internal();

  final _blocker = AppBlockerService();
  Task? _activeTask;
  Timer? _sessionTimer;

  Future<bool> startSession(Task task) async {
    // Check permissions first
    if (!await _blocker.hasAllPermissions()) {
      return false;
    }

    // End any existing session
    await endSession();

    // Block apps for this task
    if (task.blockedApps.isNotEmpty) {
      await _blocker.blockApps(task.blockedApps);
    }

    _activeTask = task;
    
    // Optional: Auto-end session after duration
    if (task.endTime != null) {
      final duration = _calculateDuration(task);
      _sessionTimer = Timer(duration, () => endSession());
    }

    return true;
  }

  Future<void> endSession() async {
    if (_activeTask != null && _activeTask!.blockedApps.isNotEmpty) {
      // Unblock apps from active task
      for (final pkg in _activeTask!.blockedApps) {
        await _blocker.unblockApp(pkg);
      }
    }

    _sessionTimer?.cancel();
    _activeTask = null;
  }

  Task? get activeTask => _activeTask;
  bool get hasActiveSession => _activeTask != null;

  Duration _calculateDuration(Task task) {
    // Calculate based on task times
    // ...
    return const Duration(hours: 1);
  }
}
```

## UI Helper: Permission Check Widget

```dart
// lib/widgets/permission_check_widget.dart
class PermissionCheckWidget extends StatelessWidget {
  final Widget child;
  final VoidCallback onPermissionsMissing;

  const PermissionCheckWidget({
    super.key,
    required this.child,
    required this.onPermissionsMissing,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AppBlockerService().hasAllPermissions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.data!) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'Permissions Required',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('App blocking needs additional permissions'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onPermissionsMissing,
                  icon: const Icon(Icons.security),
                  label: const Text('Grant Permissions'),
                ),
              ],
            ),
          );
        }

        return child;
      },
    );
  }
}

// Usage:
PermissionCheckWidget(
  child: YourTaskStartButton(),
  onPermissionsMissing: () => Navigator.pushNamed(context, '/permissions'),
)
```

## Common Patterns

### Pattern 1: Safe Blocking with Error Handling
```dart
Future<void> safeBlockApps(List<String> packages) async {
  try {
    final blocker = AppBlockerService();
    
    if (!await blocker.hasAllPermissions()) {
      throw Exception('Permissions not granted');
    }
    
    for (final pkg in packages) {
      final success = await blocker.blockApp(pkg);
      if (!success) {
        print('⚠️ Failed to block $pkg');
      }
    }
  } catch (e) {
    print('❌ Error blocking apps: $e');
    // Show error to user
  }
}
```

### Pattern 2: Conditional Blocking
```dart
Future<void> blockAppsIfEnabled(Task task) async {
  // Only block if user has blocking enabled in settings
  final settings = await getUserSettings();
  if (!settings.appBlockingEnabled) {
    return;
  }
  
  await AppBlockerService().blockApps(task.blockedApps);
}
```

### Pattern 3: Smart Unblocking
```dart
Future<void> smartUnblock() async {
  // Only unblock if no other tasks are active that block the same apps
  final activeTasks = await getActiveTasks();
  final allBlockedApps = activeTasks
      .expand((t) => t.blockedApps)
      .toSet();
  
  final currentBlocked = await AppBlockerService().getBlockedApps();
  
  for (final pkg in currentBlocked) {
    if (!allBlockedApps.contains(pkg)) {
      await AppBlockerService().unblockApp(pkg);
    }
  }
}
```

---

**Ready to integrate!** Use these examples to add app blocking to your task workflow.

