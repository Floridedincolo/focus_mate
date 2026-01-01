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
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.content.Context
import android.graphics.drawable.GradientDrawable
import android.widget.LinearLayout.LayoutParams
import android.widget.Button
import android.view.animation.AccelerateDecelerateInterpolator

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

    // Try multiple strategies to get app icon and label
    private fun loadAppIconAndLabel(pkg: String): Pair<Drawable?, String?> {
        var icon: Drawable? = null
        var label: String? = null

        try {
            icon = packageManager.getApplicationIcon(pkg)
            try {
                val ai = packageManager.getApplicationInfo(pkg, 0)
                label = packageManager.getApplicationLabel(ai)?.toString()
            } catch (_: Exception) { }
            Log.d("AppAccessibilityService", "packageManager.getApplicationIcon -> success for $pkg")
            return Pair(icon, label)
        } catch (e: Exception) {
            Log.w("AppAccessibilityService", "getApplicationIcon failed: ${e.message}")
        }

        try {
            val ai = packageManager.getApplicationInfo(pkg, PackageManager.GET_META_DATA)
            icon = ai.loadIcon(packageManager)
            label = ai.loadLabel(packageManager)?.toString()
            Log.d("AppAccessibilityService", "ApplicationInfo.loadIcon -> success for $pkg")
            return Pair(icon, label)
        } catch (e: Exception) {
            Log.w("AppAccessibilityService", "ApplicationInfo.loadIcon failed: ${e.message}")
        }

        try {
            val pkgContext = createPackageContext(pkg, Context.CONTEXT_IGNORE_SECURITY or Context.CONTEXT_INCLUDE_CODE)
            try {
                icon = pkgContext.packageManager.getApplicationIcon(pkg)
                val ai = pkgContext.packageManager.getApplicationInfo(pkg, 0)
                label = pkgContext.packageManager.getApplicationLabel(ai)?.toString()
                Log.d("AppAccessibilityService", "createPackageContext -> success for $pkg")
                return Pair(icon, label)
            } catch (e: Exception) {
                Log.w("AppAccessibilityService", "packageContext.getApplicationIcon failed: ${e.message}")
            }
        } catch (e: Exception) {
            Log.w("AppAccessibilityService", "createPackageContext failed: ${e.message}")
        }

        return Pair(null, null)
    }

    // Modern, aesthetic overlay design
    private fun showOverlay(packageName: String) {
        if (overlayShown) return

        // Request overlay permission for THIS app (our package) if missing
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            Log.w("AppAccessibilityService", "No overlay permission. Requesting user to grant it for this app.")
            val myPkg = this.packageName
            val it = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                data = android.net.Uri.parse("package:$myPkg")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            try {
                startActivity(it)
            } catch (e: Exception) {
                Log.w("AppAccessibilityService", "Failed to start overlay permission intent: ${e.message}")
            }
            return
        }

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        // Backdrop full-screen dim (Darker for better focus)
        val backdrop = FrameLayout(this)
        backdrop.setBackgroundColor(Color.parseColor("#D9000000")) // ~85% opacity black

        val scale = resources.displayMetrics.density
        val (iconDrawable, appLabel) = loadAppIconAndLabel(packageName)
        val appName = appLabel ?: "Blocked App"

        // Main Card Container
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL

            // Modern white card with rounded corners
            val bg = GradientDrawable().apply {
                cornerRadius = 32f * scale
                setColor(Color.WHITE)
            }
            background = bg

            // Padding inside the card
            setPadding((32 * scale).toInt(), (40 * scale).toInt(), (32 * scale).toInt(), (32 * scale).toInt())

            // Elevation
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                elevation = 24f * scale
            }

            // Layout params for the card itself (width match parent with margins handled by parent frame)
            layoutParams = FrameLayout.LayoutParams(
                (300 * scale).toInt(), // Fixed width for consistency
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER
            )
        }

        // 1. Icon Container (Soft background circle)
        val iconSize = (80 * scale).toInt()
        val iconContainer = FrameLayout(this).apply {
            val bg = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#F3F4F6")) // Very light gray/blue
            }
            background = bg
            layoutParams = LinearLayout.LayoutParams(iconSize, iconSize).apply {
                bottomMargin = (24 * scale).toInt()
            }
        }

        // 2. The App Icon
        if (iconDrawable != null) {
            val iconView = ImageView(this).apply {
                setImageDrawable(iconDrawable)
                layoutParams = FrameLayout.LayoutParams((48 * scale).toInt(), (48 * scale).toInt(), Gravity.CENTER)
            }
            iconContainer.addView(iconView)
        } else {
            // Fallback letter
            val letter = appName.firstOrNull()?.toString()?.uppercase() ?: "?"
            val letterView = TextView(this).apply {
                text = letter
                textSize = 32f
                setTextColor(Color.parseColor("#6B7280")) // Cool gray
                gravity = Gravity.CENTER
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                layoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
            }
            iconContainer.addView(letterView)
        }
        card.addView(iconContainer)

        // 3. "Stay Focused" Label (Small, uppercase, tracking)
        val subtitle = TextView(this).apply {
            text = "FOCUS MODE ACTIVE"
            textSize = 12f
            setTextColor(Color.parseColor("#9CA3AF")) // Light gray
            gravity = Gravity.CENTER
            letterSpacing = 0.15f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply {
                bottomMargin = (8 * scale).toInt()
            }
        }
        card.addView(subtitle)

        // 4. App Name Title
        val title = TextView(this).apply {
            text = appName
            textSize = 24f
            setTextColor(Color.parseColor("#111827")) // Almost black
            gravity = Gravity.CENTER
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
            layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply {
                bottomMargin = (12 * scale).toInt()
            }
        }
        card.addView(title)

        // 5. Motivational Message
        val message = TextView(this).apply {
            text = "This app is blocked to help you reach your goals."
            textSize = 15f
            setTextColor(Color.parseColor("#6B7280")) // Cool gray
            gravity = Gravity.CENTER
            // setLineSpacing(8f, 1f) // Optional: improve readability
            layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply {
                bottomMargin = (32 * scale).toInt()
            }
        }
        card.addView(message)

        // 6. Action Button (Pill shaped, gradient or solid color)
        val button = Button(this).apply {
            text = "Go back to focus"
            textSize = 16f
            setTextColor(Color.WHITE)
            isAllCaps = false
            stateListAnimator = null // Remove default shadow for cleaner look

            val btnBg = GradientDrawable().apply {
                cornerRadius = 100f * scale // Pill shape
                setColor(Color.parseColor("#2563EB")) // Modern Blue
            }
            background = btnBg

            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, (56 * scale).toInt())

            setOnClickListener { removeOverlay() }
        }
        card.addView(button)

        // Add card to backdrop
        backdrop.addView(card)

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_DIM_BEHIND, // Ensure dimming works if supported
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.CENTER
        params.dimAmount = 0.5f // Additional system dim

        try {
            windowManager?.addView(backdrop, params)
            overlayView = backdrop
            overlayShown = true
            Log.d("AppAccessibilityService", "Overlay displayed for $packageName")

            // Animation: Slide up and Fade in
            card.alpha = 0f
            card.translationY = 100f * scale
            card.animate()
                .alpha(1f)
                .translationY(0f)
                .setInterpolator(AccelerateDecelerateInterpolator())
                .setDuration(400)
                .start()

        } catch (e: Exception) {
            Log.e("AppAccessibilityService", "Failed to add overlay view: ${e.message}")
            overlayShown = false
            overlayView = null
            return
        }

        // Auto-remove after delay (optional, maybe longer now since it looks nice)
        Handler(Looper.getMainLooper()).postDelayed({ removeOverlay() }, 4000)
    }

    private fun removeOverlay() {
        if (!overlayShown) return
        try {
            windowManager?.removeViewImmediate(overlayView)
        } catch (e: Exception) {
            Log.w("AppAccessibilityService", "Error removing overlay: ${e.message}")
            try {
                if (overlayView != null) windowManager?.removeView(overlayView)
            } catch (_: Exception) { }
        }
        overlayView = null
        overlayShown = false
        Log.d("AppAccessibilityService", "Overlay removed")
    }

    override fun onInterrupt() {
        removeOverlay()
    }
}
