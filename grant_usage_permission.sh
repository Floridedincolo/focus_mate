#!/bin/bash

# Grant Usage Access Permission Helper
export PATH="$PATH:$HOME/Library/Android/sdk/platform-tools"

echo "🔓 Granting Usage Access Permission"
echo "===================================="
echo ""

echo "Opening Usage Access settings..."
adb shell am start -a android.settings.USAGE_ACCESS_SETTINGS
sleep 2

echo ""
echo "👉 ON YOUR EMULATOR:"
echo "   1. Look for 'FocusMate' or 'focus_mate' in the list"
echo "   2. Tap on it"
echo "   3. Toggle the switch to ON"
echo "   4. You may see a warning - tap 'Allow' or 'OK'"
echo ""
echo "Press Enter when you've done this..."
read

echo ""
echo "✅ Great! Now let's test again..."
echo ""

# Return to FocusMate
echo "Opening FocusMate app..."
adb shell am start -n com.example.focus_mate/.MainActivity
sleep 1

echo ""
echo "👉 NOW:"
echo "   1. Tap the ORANGE BUG ICON (🐛) again"
echo "   2. Tap 'Block YouTube & Test'"
echo "   3. This time it should work!"
echo ""
echo "Monitoring logs..."
echo "=================="
echo ""

# Show live logs
adb logcat -c
adb logcat | grep -E "flutter.*📋|flutter.*🚀|flutter.*✅|flutter.*❌|BlockApp"

