# Block App Plugin Fix

## Problem
The `block_app` plugin (v0.0.1) from pub.dev has a compilation bug that causes the error:
```
e: Unresolved reference 'ServiceInfo'.
```

## Root Cause
The plugin's `AppBlockingService.kt` file is missing critical imports:
- `android.content.pm.ServiceInfo` (main issue)
- `android.app.Service`
- `android.app.Notification`
- `android.app.NotificationChannel`
- `android.app.NotificationManager`
- Several other Android imports

## Solution Applied

### 1. Updated `android/app/build.gradle.kts`
```kotlin
android {
    compileSdk = 34  // Changed from flutter.compileSdkVersion
    
    defaultConfig {
        minSdk = 29  // Changed from 23 (required for ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        // ... other settings
    }
}
```

### 2. Fixed `block_app` Plugin
The `AppBlockingService.kt` file in `~/.pub-cache/hosted/pub.dev/block_app-0.0.1/` was corrected to include all necessary imports.

## How to Reapply the Fix

If you run `flutter pub cache clean` or the fix gets lost, use the provided script:

```bash
./fix_block_app.sh
```

Or manually apply the fix by running:
```bash
flutter pub get
./fix_block_app.sh
```

## Long-term Solutions

1. **Report the issue** to the block_app plugin maintainer on pub.dev
2. **Consider alternatives** like:
   - `app_usage` for monitoring
   - `device_apps` for app management
   - Custom implementation using platform channels
3. **Fork the plugin** and publish your own fixed version

## Build Commands

After applying the fix:
```bash
flutter clean
flutter pub get
flutter build apk --debug
```

## Notes
- The fix modifies files in your pub cache (`~/.pub-cache/`)
- The fix persists until you clean the pub cache
- Minimum Android SDK is now 29 (Android 10+)
- This is required for the plugin's foreground service functionality

