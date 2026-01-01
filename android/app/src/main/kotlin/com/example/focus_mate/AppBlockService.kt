package com.example.focus_mate

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.WindowManager
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import android.widget.LinearLayout
import android.graphics.PixelFormat
import android.content.Intent
import android.util.Log
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.graphics.drawable.Drawable
import android.graphics.Color

class AppBlockService : AccessibilityService() {

    private var overlayView: View? = null
    private var windowManager: WindowManager? = null
    private var overlayShown = false
    private var lastActionTime = 0L

    private val blockedApps = listOf("com.google.android.youtube")

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val packageName = event.packageName?.toString() ?: return
        Log.d("AppAccessibilityService", "Foreground app: $packageName")

        if (blockedApps.contains(packageName)) {
            val now = System.currentTimeMillis()
            if (now - lastActionTime < 1000) return
            lastActionTime = now

            Log.d("AppAccessibilityService", "Blocked app detected → HOME + OVERLAY")
            sendUserToHome()
            showOverlay(packageName)
        }
    }

    private fun sendUserToHome() {
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }

    private fun showOverlay(packageName: String) {
        if (overlayShown) return

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        val layout = FrameLayout(this)
        layout.setBackgroundColor(0xAA000000.toInt()) // semi-transparent negru

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }

        val scale = resources.displayMetrics.density
        val iconSizeInPx = (80 * scale + 0.5f).toInt() // 80dp

        // Încercăm să obținem iconița aplicației
        val iconDrawable: Drawable? = try {
            packageManager.getApplicationIcon(packageName)
        } catch (e: Exception) {
            Log.e("AppAccessibilityService", "Failed to get icon for $packageName: ${e.message}")
            null
        }

        // Adăugăm fie iconița, fie fallback-ul
        if (iconDrawable != null) {
            val iconView = ImageView(this).apply {
                setImageDrawable(iconDrawable)
                layoutParams = LinearLayout.LayoutParams(iconSizeInPx, iconSizeInPx).apply {
                    bottomMargin = (16 * scale + 0.5f).toInt() // 16dp
                }
            }
            container.addView(iconView)
            Log.d("AppAccessibilityService", "Icon successfully loaded for $packageName")
        } else {
            // fallback: prima literă din numele aplicației
            val appLabel = try {
                packageManager.getApplicationLabel(
                    packageManager.getApplicationInfo(packageName, 0)
                ).toString()
            } catch (e: Exception) {
                "?"
            }
            val letter = appLabel.firstOrNull()?.toString() ?: "?"
            val textFallback = TextView(this).apply {
                text = letter
                textSize = 48f
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
                setBackgroundColor(Color.DKGRAY)
                layoutParams = LinearLayout.LayoutParams(iconSizeInPx, iconSizeInPx).apply {
                    bottomMargin = (16 * scale + 0.5f).toInt()
                }
            }
            container.addView(textFallback)
            Log.d("AppAccessibilityService", "Using fallback icon for $packageName: $letter")
        }

        // Text "Blocked"
        val textView = TextView(this).apply {
            text = "Blocked"
            textSize = 24f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
        }

        container.addView(textView)

        layout.addView(container, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
            Gravity.CENTER
        ))

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.CENTER

        windowManager?.addView(layout, params)
        overlayView = layout
        overlayShown = true

        Handler(Looper.getMainLooper()).postDelayed({
            removeOverlay()
        }, 2000)

        Log.d("AppAccessibilityService", "Overlay displayed for $packageName")
    }

    private fun removeOverlay() {
        if (!overlayShown) return
        windowManager?.removeView(overlayView)
        overlayView = null
        overlayShown = false
        Log.d("AppAccessibilityService", "Overlay removed")
    }

    override fun onInterrupt() {
        removeOverlay()
    }
}
