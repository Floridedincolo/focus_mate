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
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.content.SharedPreferences

class AppBlockService : AccessibilityService() {

    private var overlayView: View? = null
    private var windowManager: WindowManager? = null
    private var overlayShown = false
    private var lastActionTime = 0L

    private var blockedApps: MutableSet<String> = mutableSetOf()
    private var isWhitelist: Boolean = false
    private var currentTaskName: String? = null
    private var updateReceiver: BroadcastReceiver? = null
    private var prefsListener: SharedPreferences.OnSharedPreferenceChangeListener? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        try {
            loadBlockedApps()
            // Înregistrăm receiver-ul AICI pentru a asigura că este activ când serviciul este conectat
            if (updateReceiver == null) {
                registerUpdateReceiver()
            }
            // Înregistrăm un listener pentru SharedPreferences ca fallback robust
            val prefs = getSharedPreferences("focus_mate_prefs", Context.MODE_PRIVATE)
            prefsListener = SharedPreferences.OnSharedPreferenceChangeListener { sharedPrefs, key ->
                if (key == "blocked_apps" || key == "current_task_name" || key == "is_whitelist") {
                    Log.d("AppAccessibilityService", "🔔 SharedPreferences change detected for key: $key")
                    val oldSize = blockedApps.size
                    loadBlockedApps()
                    Log.d("AppAccessibilityService", "🔄 Blocked apps refreshed via prefs listener: $oldSize → ${blockedApps.size} apps, task: $currentTaskName")
                }
            }
            prefsListener?.let { prefs.registerOnSharedPreferenceChangeListener(it) }
            Log.d("AppAccessibilityService", "🔌 Service connected – blocked apps reloaded, receiver registered")
        } catch (e: Exception) {
            Log.e("AppAccessibilityService", "❌ Error in onServiceConnected: ${e.message}", e)
        }
    }

    companion object {
        // Packages that must NEVER be blocked regardless of whitelist/blacklist mode.
        // Blocking these would lock the user out of their device.
        private val SYSTEM_EXEMPT_PACKAGES = setOf(
            "com.example.focus_mate",                    // Our own app
            "com.google.android.apps.nexuslauncher",     // Pixel launcher
            "com.sec.android.app.launcher",              // Samsung launcher
            "com.miui.home",                             // Xiaomi launcher
            "com.huawei.android.launcher",               // Huawei launcher
            "com.oppo.launcher",                         // Oppo launcher
            "com.android.launcher",                      // AOSP launcher
            "com.android.launcher3",                     // AOSP launcher 3
            "com.android.settings",                      // System settings
            "com.android.systemui",                      // System UI
            "com.android.phone",                         // Phone / dialer
            "com.android.server.telecom",                // Telecom
            "com.android.emergency",                     // Emergency info
            "com.google.android.inputmethod.latin",      // Gboard
            "com.samsung.android.honeyboard",            // Samsung keyboard
            "com.swiftkey.languageprovider",             // SwiftKey
            "com.touchtype.swiftkey",                    // SwiftKey (alt package)
            "com.android.inputmethod.latin",             // AOSP keyboard
        )
    }

    private fun loadBlockedApps() {
        val prefs: SharedPreferences = getSharedPreferences("focus_mate_prefs", Context.MODE_PRIVATE)
        blockedApps = prefs.getStringSet("blocked_apps", setOf())?.toMutableSet() ?: mutableSetOf()
        isWhitelist = prefs.getBoolean("is_whitelist", false)
        currentTaskName = prefs.getString("current_task_name", null)
        Log.d("AppAccessibilityService", "📋 Loaded ${blockedApps.size} apps, whitelist=$isWhitelist")
        Log.d("AppAccessibilityService", "📋 Current task name: $currentTaskName")
    }

    private fun registerUpdateReceiver() {
        updateReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == "com.example.focus_mate.UPDATE_BLOCKED_APPS") {
                    Log.d("AppAccessibilityService", "📡 Received UPDATE_BLOCKED_APPS broadcast")
                    val oldSize = blockedApps.size
                    loadBlockedApps()
                    Log.d(
                        "AppAccessibilityService",
                        "🔄 Blocked apps refreshed: $oldSize → ${blockedApps.size} apps"
                    )
                    blockedApps.forEach {
                        Log.d("AppAccessibilityService", "  ✓ Now blocking: $it")
                    }
                }
            }
        }

        val filter = IntentFilter("com.example.focus_mate.UPDATE_BLOCKED_APPS")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(updateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(updateReceiver, filter)
        }
        Log.d("AppAccessibilityService", " BroadcastReceiver registered for UPDATE_BLOCKED_APPS")
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            updateReceiver?.let {
                unregisterReceiver(it)
                updateReceiver = null
            }
            // Unregister prefs listener
            try {
                val prefs = getSharedPreferences("focus_mate_prefs", Context.MODE_PRIVATE)
                prefsListener?.let { prefs.unregisterOnSharedPreferenceChangeListener(it) }
                prefsListener = null
            } catch (_: Exception) { }
            removeOverlay()
            Log.d("AppAccessibilityService", "🔴 Service destroyed - cleanup completed")
        } catch (e: Exception) {
            Log.e("AppAccessibilityService", "❌ Error in onDestroy: ${e.message}", e)
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        try {
            if (blockedApps.isEmpty()) {
                loadBlockedApps()
            }

            if (event == null) return
            if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

            val packageName = event.packageName?.toString() ?: return
            Log.d("AppAccessibilityService", "Foreground app: $packageName, whitelist=$isWhitelist")

            // Never block system-exempt packages
            if (SYSTEM_EXEMPT_PACKAGES.contains(packageName)) return

            val shouldBlock = if (isWhitelist) {
                // Whitelist mode: block everything NOT in the list
                !blockedApps.contains(packageName)
            } else {
                // Blacklist mode: block only what IS in the list
                blockedApps.contains(packageName)
            }

            Log.d("AppAccessibilityService", "Should block $packageName? $shouldBlock")

            if (shouldBlock) {
                val now = System.currentTimeMillis()
                if (now - lastActionTime < 1000) return
                lastActionTime = now

                Log.d("AppAccessibilityService", "🚫 Blocked app detected → HOME + OVERLAY")
                // Mai întâi afișăm overlay-ul
                showOverlay(packageName)
                // Apoi trimitem user-ul acasă cu delay
                Handler(Looper.getMainLooper()).postDelayed({
                    sendUserToHome()
                }, 100)
            }
        } catch (e: Exception) {
            Log.e("AppAccessibilityService", "❌ Error in onAccessibilityEvent: ${e.message}", e)
            // Nu aruncăm excepția mai departe - serviciul trebuie să continue să funcționeze
        }
    }

    private fun sendUserToHome() {
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }

    private fun loadAppIconAndLabel(pkg: String): Pair<Drawable?, String?> {
        var icon: Drawable? = null
        var label: String? = null

        try {
            icon = packageManager.getApplicationIcon(pkg)
            label = packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0))?.toString()
            return Pair(icon, label)
        } catch (_: Exception) {}

        try {
            val ai = packageManager.getApplicationInfo(pkg, PackageManager.GET_META_DATA)
            icon = ai.loadIcon(packageManager)
            label = ai.loadLabel(packageManager)?.toString()
            return Pair(icon, label)
        } catch (_: Exception) {}

        try {
            val pkgContext = createPackageContext(pkg, Context.CONTEXT_IGNORE_SECURITY or Context.CONTEXT_INCLUDE_CODE)
            icon = pkgContext.packageManager.getApplicationIcon(pkg)
            label = pkgContext.packageManager.getApplicationLabel(pkgContext.packageManager.getApplicationInfo(pkg, 0))?.toString()
            return Pair(icon, label)
        } catch (_: Exception) {}

        return Pair(null, null)
    }

    private fun showOverlay(packageName: String) {
        if (overlayShown) {
            Log.d("AppAccessibilityService", "⚠️ Overlay already shown, skipping")
            return
        }

        // 1️⃣ Verifică permisiunea overlay
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            Log.e("AppAccessibilityService", "❌ OVERLAY PERMISSION MISSING! Cannot show overlay.")
            Log.e("AppAccessibilityService", "⚠️ Please enable 'Display over other apps' permission in Settings → Apps → FocusMate → Permissions")
            return
        }

        Log.d("AppAccessibilityService", " Overlay permission granted, showing overlay for: $packageName")

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val scale = resources.displayMetrics.density

        val (iconDrawable, appLabel) = loadAppIconAndLabel(packageName)
        val appName = appLabel ?: "Aplicație"

        val backdrop = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#AA000000"))
            isClickable = true
            isFocusable = true
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            val bg = GradientDrawable().apply {
                cornerRadius = 36f * scale
                setColor(Color.parseColor("#22FFFFFF"))
                setStroke((1 * scale).toInt(), Color.parseColor("#33FFFFFF"))
            }
            background = bg
            setPadding((32 * scale).toInt(), (48 * scale).toInt(), (32 * scale).toInt(), (40 * scale).toInt())
            layoutParams = FrameLayout.LayoutParams(
                (320 * scale).toInt(),
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER
            )
        }

        val iconView = ImageView(this).apply {
            setImageDrawable(iconDrawable)
            layoutParams = LinearLayout.LayoutParams((72 * scale).toInt(), (72 * scale).toInt()).apply {
                bottomMargin = (24 * scale).toInt()
            }
        }
        card.addView(iconView)

        // Citește numele task-ului curent din SharedPreferences (setat de Flutter)
        val taskName = currentTaskName

        val title = TextView(this).apply {
            text = "$appName is blocked"
            textSize = 22f
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply {
                bottomMargin = (12 * scale).toInt()
            }
        }
        card.addView(title)

        // Afișează numele task-ului dacă este disponibil
        if (!taskName.isNullOrBlank()) {
            val focusLabel = TextView(this).apply {
                text = "You should focus on:"
                textSize = 14f
                setTextColor(Color.parseColor("#AAFFFFFF"))
                gravity = Gravity.CENTER
                typeface = android.graphics.Typeface.create("sans-serif-light", android.graphics.Typeface.NORMAL)
                layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply {
                    topMargin = (8 * scale).toInt()
                }
            }
            card.addView(focusLabel)

            val taskNameView = TextView(this).apply {
                text = taskName
                textSize = 18f
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
                typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.BOLD)
                layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply {
                    topMargin = (4 * scale).toInt()
                    bottomMargin = (32 * scale).toInt()
                }
            }
            card.addView(taskNameView)
        } else {
            val subtitle = TextView(this).apply {
                text = "by Focus Mate"
                textSize = 16f
                setTextColor(Color.parseColor("#AAFFFFFF"))
                gravity = Gravity.CENTER
                typeface = android.graphics.Typeface.create("sans-serif-light", android.graphics.Typeface.NORMAL)
                layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply {
                    bottomMargin = (32 * scale).toInt()
                }
            }
            card.addView(subtitle)
        }

        val btnExit = Button(this).apply {
            text = "Go Back"
            setTextColor(Color.BLACK)
            isAllCaps = false
            textSize = 16f
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
            val btnBg = GradientDrawable().apply {
                cornerRadius = 24f * scale
                setColor(Color.WHITE)
            }
            background = btnBg
            elevation = 8f * scale
            layoutParams = LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, (58 * scale).toInt()).apply {
                bottomMargin = (16 * scale).toInt()
            }
            setOnClickListener { removeOverlay() }
        }
        card.addView(btnExit)

        val btnContinue = TextView(this).apply {
            text = "I need 2 minutes"
            textSize = 14f
            setTextColor(Color.parseColor("#88FFFFFF"))
            gravity = Gravity.CENTER
            setPadding(0, (12 * scale).toInt(), 0, (12 * scale).toInt())
            setOnClickListener {
                this.text = "Wait 5 seconds..."
                this.isEnabled = false
                Handler(Looper.getMainLooper()).postDelayed({
                    removeOverlay()
                }, 5000)
            }
        }
        //card.addView(btnContinue)

        backdrop.addView(card)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED or
                    WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM,
            PixelFormat.TRANSLUCENT
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            params.blurBehindRadius = 60
            params.flags = params.flags or WindowManager.LayoutParams.FLAG_BLUR_BEHIND
        }

        try {
            windowManager?.addView(backdrop, params)
            overlayView = backdrop
            overlayShown = true

            card.alpha = 0f
            card.scaleX = 0.85f
            card.scaleY = 0.85f
            card.animate()
                .alpha(1f)
                .scaleX(1f)
                .scaleY(1f)
                .setDuration(450)
                .setInterpolator(AccelerateDecelerateInterpolator())
                .start()

        } catch (e: Exception) {
            Log.e("FocusMate", "Nu s-a putut afișa overlay-ul: ${e.message}")
            overlayShown = false
        }
    }

    private fun removeOverlay() {
        if (!overlayShown) return
        try {
            windowManager?.removeViewImmediate(overlayView)
        } catch (e: Exception) {
            Log.w("AppAccessibilityService", "Error removing overlay: ${e.message}")
            try { if (overlayView != null) windowManager?.removeView(overlayView) } catch (_: Exception) {}
        }
        overlayView = null
        overlayShown = false
        Log.d("AppAccessibilityService", "Overlay removed")
    }

    override fun onInterrupt() {
        removeOverlay()
    }
}
