#!/bin/bash

# Quick Test Script for App Blocking Feature
# Add ADB to PATH
export PATH="$PATH:$HOME/Library/Android/sdk/platform-tools"

echo "🧪 App Blocking Test Helper"
echo "============================"
echo ""

# Check if device is connected
if ! adb devices | grep -q "device$"; then
    echo "❌ No Android device detected!"
    echo "Please make sure your emulator or device is running."
    exit 1
fi

echo "📱 Device detected!"
echo ""

# Function to show menu
show_menu() {
    echo "What would you like to do?"
    echo ""
    echo "1) Grant Overlay Permission"
    echo "2) Grant Usage Access Permission"
    echo "3) Open FocusMate App"
    echo "4) View Live Logs (for blocking tests)"
    echo "5) Block YouTube (via ADB command)"
    echo "6) Open YouTube App"
    echo "7) Clear App Data & Restart"
    echo "8) Exit"
    echo ""
    read -p "Enter choice [1-8]: " choice

    case $choice in
        1)
            echo "🔓 Opening overlay permission settings..."
            adb shell am start -a android.settings.action.MANAGE_OVERLAY_PERMISSION -d package:com.example.focus_mate
            echo "✅ Please enable 'Display over other apps' permission"
            echo ""
            read -p "Press Enter when done..."
            show_menu
            ;;
        2)
            echo "📊 Opening usage access settings..."
            adb shell am start -a android.settings.USAGE_ACCESS_SETTINGS
            echo "✅ Please find and enable 'FocusMate' in the list"
            echo ""
            read -p "Press Enter when done..."
            show_menu
            ;;
        3)
            echo "📲 Opening FocusMate..."
            adb shell am start -n com.example.focus_mate/.MainActivity
            echo "✅ App should be opening now"
            echo ""
            read -p "Press Enter to continue..."
            show_menu
            ;;
        4)
            echo "📋 Starting live log monitoring..."
            echo "Press Ctrl+C to stop"
            echo "============================"
            adb logcat -c  # Clear logs first
            adb logcat | grep -E "flutter|BlockApp|AppBlocking|youtube|Overlay"
            show_menu
            ;;
        5)
            echo "🚫 This would need the Flutter code to be called."
            echo "Please use the test page in the app (bug icon 🐛)"
            echo ""
            read -p "Press Enter to continue..."
            show_menu
            ;;
        6)
            echo "📺 Opening YouTube..."
            adb shell am start -n com.google.android.youtube/.HomeActivity
            echo "✅ YouTube should be opening now"
            echo "If blocking is working, you should see an overlay!"
            echo ""
            read -p "Press Enter to continue..."
            show_menu
            ;;
        7)
            echo "🗑️  Clearing app data..."
            adb shell pm clear com.example.focus_mate
            echo "🔄 Restarting app..."
            adb shell am start -n com.example.focus_mate/.MainActivity
            echo "✅ App data cleared and restarted"
            echo ""
            read -p "Press Enter to continue..."
            show_menu
            ;;
        8)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo "❌ Invalid choice. Please try again."
            echo ""
            show_menu
            ;;
    esac
}

# Show the menu
show_menu

