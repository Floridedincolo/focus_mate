#!/bin/bash

# Super Simple App Blocking Test
# Just run this and follow the prompts!

export PATH="$PATH:$HOME/Library/Android/sdk/platform-tools"

echo "🧪 Testing App Blocking Feature"
echo "================================"
echo ""

# Check device
if ! adb devices | grep -q "device$"; then
    echo "❌ No device found! Start your emulator first."
    exit 1
fi

echo "✅ Device connected"
echo ""

# Check if app is installed
if ! adb shell pm list packages | grep -q "com.example.focus_mate"; then
    echo "❌ FocusMate app not installed!"
    echo "Run: flutter run"
    exit 1
fi

echo "✅ App installed"
echo ""

echo "📋 Step-by-step testing:"
echo "------------------------"
echo ""

echo "1️⃣  Opening FocusMate app..."
adb shell am start -n com.example.focus_mate/.MainActivity
sleep 2

echo ""
echo "👉 NOW IN THE APP:"
echo "   - Look for ORANGE BUG ICON (🐛) in top-right corner"
echo "   - Tap the bug icon"
echo "   - Tap 'Block YouTube & Test'"
echo "   - Watch for success message"
echo ""
read -p "Press Enter after you've done this..."

echo ""
echo "2️⃣  Now testing if blocking works..."
echo "    Opening YouTube..."
adb shell am start -n com.google.android.youtube/.HomeActivity
sleep 2

echo ""
echo "❓ Did you see a BLOCKING OVERLAY over YouTube?"
echo ""
read -p "Type 'yes' or 'no': " answer

if [[ "$answer" == "yes" ]]; then
    echo ""
    echo "✅ ✅ ✅ SUCCESS! App blocking is working! ✅ ✅ ✅"
    echo ""
    echo "You can now:"
    echo "- Integrate blocking into your task system"
    echo "- Customize the blocking screen"
    echo "- Add more apps to block"
    echo ""
else
    echo ""
    echo "❌ Blocking didn't work. Let's debug..."
    echo ""
    echo "Opening log viewer. Look for:"
    echo "  - 📋 Overlay permission"
    echo "  - 🚀 Attempting to block"
    echo "  - ✅ Block result"
    echo ""
    echo "Press Ctrl+C to stop logs"
    echo ""
    adb logcat | grep -E "flutter|BlockApp|Overlay|youtube"
fi

