# App Blocking Permissions Setup Guide

## What Was Fixed

I've completely refactored the app blocking implementation to fix the permission issues. Here's what changed:

### 1. **Removed Blocking Logic from App Startup** (`lib/main.dart`)
   - The app no longer tries to block apps during initialization
   - This prevents crashes and permission errors on startup
   - The app now launches cleanly without any blocking logic

### 2. **Created App Blocker Service** (`lib/services/app_blocker_service.dart`)
   - A centralized service to manage all app blocking functionality
   - Handles permissions checking and requesting
   - Provides easy-to-use methods for blocking/unblocking apps
   - Includes error handling and debugging

### 3. **Added Permissions Page** (`lib/pages/permissions_page.dart`)
   - A dedicated UI for managing app blocking permissions
   - Shows the status of required permissions:
     - **Display Over Other Apps**: Allows blocking screen overlay
     - **Usage Access**: Detects when blocked apps are opened
   - Provides one-tap buttons to grant each permission
   - Shows helpful instructions on how the feature works
   - Pull to refresh to check permission status after granting

### 4. **Integrated with Profile Page** (`lib/pages/profile.dart`)
   - Added "App Blocking Permissions" menu item under Preferences
   - Easy access to permission settings

## How to Use

### Step 1: Grant Permissions

1. Launch the app
2. Navigate to **Profile** (bottom navigation)
3. Scroll to **Preferences** section
4. Tap on **"App Blocking Permissions"**
5. You'll see two permission requirements:

   **a) Display Over Other Apps**
   - Tap the "Grant" button
   - Android will open the system settings
   - Find "FocusMate" in the list
   - Toggle on "Display over other apps"
   - Go back to the app

   **b) Usage Access**
   - Tap the "Grant" button
   - Android will open the Usage Access settings
   - Find "FocusMate" in the list
   - Toggle on the permission
   - Go back to the app

6. Pull down to refresh and verify both permissions show green checkmarks ✅

### Step 2: Use App Blocking (Future Implementation)

The permissions are now ready! Next steps to implement:

1. **Add blocked apps list to Task model** - Store which apps to block per task
2. **App selection UI** - Let users select apps to block when creating/editing tasks
3. **Start blocking when task begins** - Automatically block selected apps
4. **Stop blocking when task ends** - Automatically unblock apps

## Technical Details

### Service Architecture

```dart
// Initialize the service
final blocker = AppBlockerService();

// Check permissions
bool hasOverlay = await blocker.hasOverlayPermission();
bool hasUsage = await blocker.hasUsageStatsPermission();
bool hasAll = await blocker.hasAllPermissions();

// Request permissions (opens system settings)
await blocker.requestOverlayPermission();
await blocker.requestUsageStatsPermission();

// Block/unblock apps
await blocker.blockApp('com.google.android.youtube');
await blocker.unblockApp('com.google.android.youtube');

// Get blocked apps
List<String> blocked = await blocker.getBlockedApps();

// Block multiple apps
await blocker.blockApps(['com.facebook.katana', 'com.instagram.android']);

// Unblock all apps
await blocker.unblockAllApps();
```

### Files Modified/Created

**Created:**
- `lib/services/app_blocker_service.dart` - Service layer for app blocking
- `lib/pages/permissions_page.dart` - UI for permission management

**Modified:**
- `lib/main.dart` - Removed startup blocking logic, added permissions route
- `lib/pages/profile.dart` - Added permissions menu item

## Why This Approach Works

### Previous Issues:
1. ❌ App tried to request permissions during startup
2. ❌ `requestOverlayPermission()` returned immediately (no waiting for user)
3. ❌ Permission checks happened before user could grant them
4. ❌ Service crashed because permissions weren't granted

### New Approach:
1. ✅ App launches cleanly without blocking logic
2. ✅ User manually navigates to permissions page when ready
3. ✅ Clear instructions guide user through granting each permission
4. ✅ Pull-to-refresh verifies permissions are granted
5. ✅ Blocking service only runs when permissions are confirmed

## Next Steps for Implementation

### 1. Update Task Model
Add a `blockedApps` field to store package names:

```dart
class Task {
  // ...existing fields...
  final List<String> blockedApps;
  
  Task({
    // ...existing parameters...
    this.blockedApps = const [],
  });
}
```

### 2. Create App Selection UI
Add a page/dialog to select apps to block:
- Show list of installed apps
- Allow multi-select
- Save to task

### 3. Implement Task Start/End Blocking
```dart
// When task starts
await AppBlockerService().blockApps(task.blockedApps);

// When task ends
await AppBlockerService().unblockApps(task.blockedApps);
```

## Testing

1. ✅ App launches without crashes
2. ✅ Permissions page is accessible from Profile
3. ✅ Permission requests open system settings
4. ✅ Permission status updates correctly
5. ⏳ Next: Test blocking when integrated with tasks

## Important Notes

- **Minimum Android SDK**: 29 (Android 10+)
- **Required Permissions**: 
  - `SYSTEM_ALERT_WINDOW` (Display over other apps)
  - `PACKAGE_USAGE_STATS` (Usage access)
  - `FOREGROUND_SERVICE_MEDIA_PROJECTION` (Service type)
- **Emulator**: Works on Android emulators (tested on sdk gphone64 arm64)
- **Real Device**: Should work on physical devices running Android 10+

## Troubleshooting

### Issue: Permissions don't grant
- **Solution**: Make sure you're enabling the permission in the system settings that open

### Issue: App still crashes when blocking
- **Solution**: Verify both permissions are granted (green checkmarks) before attempting to block

### Issue: Blocking screen doesn't appear
- **Solution**: Check that `Display over other apps` permission is granted and try restarting the app

---

**Ready to test!** Run the app and grant the permissions following the steps above.

