# 🚀 QUICK START - Test App Blocking NOW

## Step 1: Open the App
The app should be running on your emulator already.

## Step 2: Find the Orange Bug Icon
Look at the **TOP RIGHT** of the home screen. You should see:
- An **orange bug icon** (🐛) next to your profile picture
- If you don't see it, the hot restart didn't work properly

## Step 3: Can't See the Bug Icon?
If you don't see the orange bug icon, run this command:

```bash
cd /Users/teo/Documents/facultate/liceenta/focus_mate
flutter run
```

Then press **'R'** (capital R) when prompted to do a hot restart.

## Step 4: Use the Test Script (EASIEST METHOD)

I created a helper script for you:

```bash
cd /Users/teo/Documents/facultate/liceenta/focus_mate
./test_blocking.sh
```

This will show you a menu with options to:
1. Grant permissions
2. Open the app
3. View live logs
4. Test YouTube opening

## Step 5: Manual Testing

### A) Grant Permissions First

**Overlay Permission:**
```bash
export PATH="$PATH:$HOME/Library/Android/sdk/platform-tools"
adb shell am start -a android.settings.action.MANAGE_OVERLAY_PERMISSION -d package:com.example.focus_mate
```
Then enable "Display over other apps"

**Usage Access:**
```bash
adb shell am start -a android.settings.USAGE_ACCESS_SETTINGS
```
Then find and enable "FocusMate"

### B) Test Blocking

1. **Open FocusMate**
   ```bash
   adb shell am start -n com.example.focus_mate/.MainActivity
   ```

2. **Tap the orange bug icon (🐛)** in the top-right

3. **Tap "Block YouTube & Test"**

4. **Watch the screen** - it should show status messages

5. **Press Home button** on the device

6. **Open YouTube:**
   ```bash
   adb shell am start -n com.google.android.youtube/.HomeActivity
   ```

7. **You should see a blocking overlay!**

## Step 6: Watch Logs

Open a new terminal and run:
```bash
export PATH="$PATH:$HOME/Library/Android/sdk/platform-tools"
adb logcat | grep -E "flutter|BlockApp|AppBlocking|Overlay"
```

Look for:
- `📋 Overlay permission: true`
- `🚀 Attempting to block YouTube...`
- `✅ Block result: true`
- `✅ Service started: true`

## Common Issues

### "I don't see the bug icon"
- The hot restart didn't apply changes
- Stop the app completely and run `flutter run` again
- Make sure you're on the HOME screen, not another page

### "Permission already granted but app says it's not"
- The app might be caching the old permission state
- Try: `adb shell pm clear com.example.focus_mate`
- Then restart the app

### "Overlay doesn't show when I open YouTube"
- Check if permissions are REALLY granted (use the script option 1 & 2)
- Check logs for error messages
- The service might have crashed - check logcat

## Video Walkthrough Alternative

If nothing works, describe what you see on screen and I'll help debug:
1. What screen are you on in the app?
2. Do you see the orange bug icon?
3. What happens when you tap it?
4. What logs do you see?

## One-Line Full Test

This command will:
1. Open app
2. Show you where to grant permissions
3. Monitor logs

```bash
cd /Users/teo/Documents/facultate/liceenta/focus_mate && ./test_blocking.sh
```

**Choose option 4** to see live logs, then manually test the blocking feature in the app!

