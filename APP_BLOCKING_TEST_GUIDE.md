# App Blocking Testing Guide

## Current Status
The app blocking feature is implemented but needs proper testing. The issue you're experiencing is that the blocking overlay is not showing up when you try to open YouTube.

## Steps to Test App Blocking

### 1. Grant Permissions
1. Open the app
2. Navigate to **Permissions** page (from profile or menu)
3. Grant both permissions:
   - **Display Over Other Apps** - Allows the blocking overlay to show
   - **Usage Access** - Allows detection of which app is opened

### 2. Use the Test Blocking Page
1. In the home screen, look for the **orange bug icon** (🐛) in the top-right
2. Tap it to open the "Test App Blocking" page
3. Click **"Block YouTube & Test"**
4. Watch the logs in your IDE/terminal for debug messages:
   - `📋 Overlay permission: true`
   - `📋 Usage Stats permission: true`
   - `🚀 Attempting to block YouTube...`
   - `✅ Block result: true`
   - `📱 Currently blocked apps: [com.google.android.youtube]`
   - `🔧 Starting blocking service...`
   - `✅ Service started: true`

### 3. Test the Blocking
1. After you see "✅ YouTube is now blocked!" message
2. **Press the Home button** on your device (minimize the FocusMate app)
3. **Open the YouTube app** from your app drawer
4. You should see a **blocking overlay** appear over YouTube

### 4. What Should Happen
- YouTube should be covered by a full-screen overlay
- The overlay should prevent you from using YouTube
- You should see a message about the app being blocked

### 5. Debugging Steps

#### Check Logcat for Blocking Service
Run this command in terminal to see live blocking logs:
```bash
# Filter for blocking-related logs
adb logcat | grep -E "BlockApp|AppBlocking|Overlay|youtube"
```

#### Common Issues

**Issue 1: "Missing permissions"**
- Solution: Go to Permissions page and grant both permissions
- Make sure to actually enable them in the Android settings that open

**Issue 2: "YouTube blocked but overlay doesn't show"**
- Possible causes:
  - Overlay permission not actually granted
  - Service not running properly
  - App detection not working
  
**Issue 3: Service crashes immediately**
- Check logcat for crash logs
- The most recent issue was `MissingForegroundServiceTypeException`
- This was fixed by adding the proper foreground service type

**Issue 4: "Overlay permission granted: false"**
- The permission check might be failing
- Try manually going to: Settings → Apps → FocusMate → Display over other apps

### 6. Manual Permission Check (Android Settings)
1. Open **Settings** on your Android device
2. Go to **Apps** → **FocusMate**
3. Check **Permissions**:
   - Look for "Display over other apps" - should be ON
4. Go back and tap **Usage access**
   - FocusMate should be listed and enabled

### 7. Expected Logs

When blocking works correctly, you should see in logcat:
```
I/flutter: Overlay permission granted: true
I/flutter: App: focus_mate (com.example.focus_mate)
I/flutter: ✅ com.google.android.youtube blocată cu succes!
I/flutter: Blocked apps after attempt: [com.google.android.youtube]
I/flutter: startBlockingService returned: true
```

When you open YouTube, you should see:
```
I/AppBlockingService: Detected foreground app: com.google.android.youtube
I/AppBlockingService: Showing blocking overlay
```

### 8. Unblock Apps
After testing, use the **"Unblock All Apps"** button in the Test Blocking page to restore normal functionality.

## Architecture Overview

The app blocking works as follows:
1. **AppBlockingService** (Kotlin) - A foreground service that runs continuously
2. It monitors which app is in the foreground every 500ms
3. When a blocked app is detected, it shows a Flutter overlay on top
4. The overlay covers the entire screen and cannot be dismissed

## Files Involved
- `lib/services/app_blocker_service.dart` - Flutter wrapper for the plugin
- `lib/pages/test_blocking_page.dart` - Test page for blocking
- `lib/pages/permissions_page.dart` - Permission management
- Plugin: `block_app` (cached in `.pub-cache`)

## Troubleshooting

If the test page shows an error, check:
1. Run `flutter pub get` to ensure the plugin is installed
2. Run `./fix_block_app.sh` if you get compilation errors
3. Rebuild the app: `flutter clean && flutter run`
4. Check Android version - works on Android 5.0+ (API 21+)

## Next Steps
1. Test on a real device (not emulator) for better reliability
2. If it works, integrate blocking into task system
3. Add custom blocking screen UI
4. Add ability to select which apps to block per task

