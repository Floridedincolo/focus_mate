# 🧪 Testing Checklist - App Blocking Permissions

## Pre-Test Setup
- [x] Code compiled successfully ✅
- [x] No errors in Dart files ✅
- [x] APK built successfully ✅

## Test 1: Clean App Launch
**Goal**: Verify app launches without crashes

1. [ ] Run `flutter run` or launch from IDE
2. [ ] App opens to Home screen
3. [ ] No crash on startup
4. [ ] Can navigate to other screens

**Expected**: App launches cleanly, no errors about YouTube blocking

**Log should show**:
```
I/flutter: [IMPORTANT:flutter/...] Using the Impeller rendering backend
```

**Log should NOT show**:
```
I/flutter: ❌ Nu s-a putut bloca com.google.android.youtube.
E/AndroidRuntime: FATAL EXCEPTION: main
```

## Test 2: Navigate to Permissions Page
**Goal**: Access the new permissions UI

1. [ ] From Home, tap Profile icon (bottom navigation)
2. [ ] Scroll down to "Preferences" section
3. [ ] Find "App Blocking Permissions" menu item
4. [ ] Tap it
5. [ ] Permissions page opens

**Expected**: Beautiful permissions page with two permission cards:
- Display Over Other Apps (❌ or ✅)
- Usage Access (❌ or ✅)

## Test 3: Grant Display Over Other Apps
**Goal**: Successfully grant overlay permission

1. [ ] On Permissions page, tap "Grant" button for "Display Over Other Apps"
2. [ ] System settings page opens
3. [ ] Find "FocusMate" (or "focus_mate") in the list
4. [ ] Toggle the permission ON
5. [ ] Press back button to return to app
6. [ ] Pull down on permissions page to refresh
7. [ ] "Display Over Other Apps" now shows ✅ green checkmark

**Android Settings Path**:
```
Settings → Apps → Special app access → Display over other apps → FocusMate
```

## Test 4: Grant Usage Access
**Goal**: Successfully grant usage stats permission

1. [ ] On Permissions page, tap "Grant" button for "Usage Access"
2. [ ] Usage access settings opens
3. [ ] Find "FocusMate" in the list
4. [ ] Toggle the permission ON
5. [ ] Press back button to return to app
6. [ ] Pull down to refresh
7. [ ] "Usage Access" now shows ✅ green checkmark

**Android Settings Path**:
```
Settings → Apps → Special app access → Usage access → FocusMate
```

## Test 5: Verify All Permissions Granted
**Goal**: Confirm both permissions are active

1. [ ] Both permissions show ✅ green checkmarks
2. [ ] Green success card appears at bottom:
   > "All permissions granted! You can now use app blocking features."

## Test 6: Test Service Functions (Optional - Developer Test)
**Goal**: Verify AppBlockerService works

Add this test code temporarily to test the service:

```dart
// In any page, add this test method:
Future<void> _testBlockingService() async {
  final blocker = AppBlockerService();
  
  // Test 1: Check permissions
  final hasAll = await blocker.hasAllPermissions();
  print('Has all permissions: $hasAll');
  
  if (hasAll) {
    // Test 2: Block YouTube
    final blocked = await blocker.blockApp('com.google.android.youtube');
    print('YouTube blocked: $blocked');
    
    // Test 3: Get blocked apps
    final blockedApps = await blocker.getBlockedApps();
    print('Blocked apps: $blockedApps');
    
    // Test 4: Unblock YouTube
    await blocker.unblockApp('com.google.android.youtube');
    print('YouTube unblocked');
  }
}
```

Call this from a button tap and check logs.

## Common Issues & Solutions

### Issue 1: Permission page doesn't open system settings
**Symptom**: Tapping "Grant" does nothing
**Solution**: Check logcat for errors, ensure MainActivity.kt is properly configured

### Issue 2: Permissions don't persist after granting
**Symptom**: Toggle ON in settings, but app shows ❌
**Solution**: Pull to refresh on permissions page, or restart app

### Issue 3: App crashes when trying to block
**Symptom**: App closes when blocking is attempted
**Solution**: Ensure BOTH permissions are granted before attempting to block

### Issue 4: Emulator doesn't have YouTube app
**Symptom**: Can't test YouTube blocking
**Solution**: Use any other app package name like:
- `com.android.chrome` (Chrome browser)
- `com.google.android.apps.messaging` (Messages)
- `com.android.settings` (Settings - careful!)

## Expected Logs (Success)

### Clean Launch:
```
I/flutter: Overlay permission granted: false
I/flutter: App: focus_mate (com.example.focus_mate)
D/WindowLayoutComponentImpl: Register WindowLayoutInfoListener...
```

### After Granting Permissions:
```
I/flutter: Overlay permission granted: true
I/flutter: ✅ All permissions available for app blocking
```

### When Blocking an App:
```
I/flutter: ✅ com.google.android.youtube blocată cu succes!
I/flutter: Blocked apps: [com.google.android.youtube]
I/flutter: Service started: true
```

## Quick Test Commands

```bash
# Build and install
cd /Users/teo/Documents/facultate/liceenta/focus_mate
flutter clean
flutter pub get
flutter build apk --debug
flutter install

# Run with logs
flutter run

# In another terminal, watch logs
flutter logs | grep -E "flutter|Permission|Block"
```

## Success Criteria ✅

The fix is successful if:
- [x] App compiles without errors
- [ ] App launches without crashing
- [ ] Can navigate to permissions page
- [ ] Can grant Display Over Other Apps permission
- [ ] Can grant Usage Access permission
- [ ] Both permissions show green checkmarks after granting
- [ ] No crashes related to overlay/blocking permissions

---

**Ready to test!** Follow the checklist above and mark items as you complete them.

**Status**: All code changes complete ✅, awaiting user testing on device/emulator.

