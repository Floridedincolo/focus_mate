package com.block_app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class AppAccessibilityService : AccessibilityService() {
    companion object {
        private const val TAG = "AppAccessibilityService"
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.DEFAULT
            notificationTimeout = 100
        }
        this.serviceInfo = info
        Log.d(TAG, "Accessibility service connected")
        super.onServiceConnected()
        Log.d(TAG, "ACCESSIBILITY CONNECTED")

        sendBroadcast(
            Intent("com.block_app.ACTION_SHOW_OVERLAY")
                .putExtra("package", "test")
        )
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        try {
            if (event == null) return
            val packageName = event.packageName?.toString() ?: return
            val action = event.eventType
            // Send broadcast to AppBlockingService asking to show/hide overlay
            val intent = Intent()
            intent.action = "com.block_app.ACTION_SHOW_OVERLAY"
            intent.putExtra("package", packageName)
            sendBroadcast(intent)
            Log.d(TAG, "Accessibility event: pkg=$packageName type=$action")
        } catch (e: Exception) {
            Log.e(TAG, "Error handling accessibility event", e)
        }
    }

    override fun onInterrupt() {
        // no-op
    }
}

