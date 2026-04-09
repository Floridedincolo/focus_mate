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
import org.json.JSONArray
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AppBlockService : AccessibilityService() {

    private var overlayView: View? = null
    private var windowManager: WindowManager? = null
    private var overlayShown = false
    private var lastActionTime = 0L

    // Variabile pentru verificarea periodică (Heartbeat)
    private var lastPackageSeen: String? = null
    private val handler = Handler(Looper.getMainLooper())
    private var tickRunnable: Runnable? = null

    companion object {
        const val PREF_PREVENTED_PREFIX = "prevented_distractions_"
        val dayFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)

        private val SYSTEM_EXEMPT_PACKAGES = setOf(
            "com.example.focus_mate", "com.google.android.apps.nexuslauncher",
            "com.sec.android.app.launcher", "com.miui.home", "com.huawei.android.launcher",
            "com.oppo.launcher", "com.android.launcher", "com.android.launcher3",
            "com.android.settings", "com.android.systemui", "com.android.phone",
            "com.android.server.telecom", "com.android.emergency",
            "com.google.android.inputmethod.latin", "com.samsung.android.honeyboard",
            "com.swiftkey.languageprovider", "com.touchtype.swiftkey", "com.android.inputmethod.latin"
        )
    }

    private var scheduledBlocks: JSONArray = JSONArray()
    private var currentTaskName: String? = null
    private var currentTaskStartTimeMs: Long = 0L
    private var currentTaskEndTimeMs: Long = 0L
    private var lastFileModified = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d("AppAccessibilityService", "🔌 Serviciu conectat – Monitorizare activă!")
        checkAndLoadSchedule()
        startPeriodicCheck()
    }

    // Pornește un timer care verifică aplicația curentă la fiecare 3 secunde
    private fun startPeriodicCheck() {
        tickRunnable = object : Runnable {
            override fun run() {
                lastPackageSeen?.let { pkg ->
                    checkBlockingLogic(pkg)
                }
                handler.postDelayed(this, 3000)
            }
        }
        handler.post(tickRunnable!!)
    }

    private fun checkAndLoadSchedule() {
        try {
            val file = File(filesDir, "schedule.json")
            if (file.exists()) {
                val currentModified = file.lastModified()
                if (currentModified > lastFileModified) {
                    val jsonString = file.readText()
                    scheduledBlocks = JSONArray(jsonString)
                    lastFileModified = currentModified
                    Log.d("AppAccessibilityService", "📄 Orar sincronizat! (${scheduledBlocks.length()} ferestre)")
                }
            }
        } catch (e: Exception) {
            Log.e("AppAccessibilityService", "❌ Eroare la citirea orarului: ${e.message}")
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        try {
            if (event == null || event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

            val packageName = event.packageName?.toString() ?: return
            lastPackageSeen = packageName

            checkBlockingLogic(packageName)
        } catch (e: Exception) {
            Log.e("AppAccessibilityService", "❌ Eroare în onAccessibilityEvent: ${e.message}")
        }
    }

    private fun checkBlockingLogic(packageName: String) {
        if (SYSTEM_EXEMPT_PACKAGES.contains(packageName)) return

        checkAndLoadSchedule()

        val now = System.currentTimeMillis()
        var shouldBlock = false
        var foundTaskName: String? = null
        var foundStartMs = 0L
        var foundEndMs = 0L

        for (i in 0 until scheduledBlocks.length()) {
            val block = scheduledBlocks.getJSONObject(i)
            val startMs = block.getLong("startMs")
            val endMs = block.getLong("endMs")

            if (now in startMs until endMs) {
                val isWhitelist = block.getBoolean("isWhitelist")
                val appsArray = block.getJSONArray("apps")
                val blockedApps = mutableSetOf<String>()
                for (j in 0 until appsArray.length()) { blockedApps.add(appsArray.getString(j)) }

                val isAppBlocked = if (isWhitelist) !blockedApps.contains(packageName) else blockedApps.contains(packageName)

                if (isAppBlocked) {
                    shouldBlock = true
                    foundTaskName = block.getString("taskName")
                    foundStartMs = startMs
                    foundEndMs = endMs
                    break
                }
            }
        }

        if (shouldBlock) {
            currentTaskName = foundTaskName
            currentTaskStartTimeMs = foundStartMs
            currentTaskEndTimeMs = foundEndMs

            // Perioadă de grație mărită la 5 secunde pentru a evita numărătoarea dublă (săritul)
            if (now - lastActionTime < 5000) return
            lastActionTime = now

            Log.d("AppAccessibilityService", "🚫 Blocare executată pentru $packageName la ora ${Date(now)}")

            // Incrementăm și extragem numărul
            val preventedCount = incrementPreventedDistractions()

            showOverlay(packageName, preventedCount)
            Handler(Looper.getMainLooper()).postDelayed({ sendUserToHome() }, 100)
        }
    }

    // AICI E MAGIA NOUĂ: Salvăm atât totalul pe zi, cât și totalul pe ora exactă!
    private fun incrementPreventedDistractions(): Int {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val now = Date()

            // 1. Găleata mare (Totalul pe Zi)
            val todayStr = dayFormat.format(now)
            val todayKey = "flutter." + PREF_PREVENTED_PREFIX + todayStr
            val currentTotal = prefs.getInt(todayKey, 0)
            val newTotal = currentTotal + 1
            prefs.edit().putInt(todayKey, newTotal).apply()

            // 2. Găleata mică (Totalul pe Ora curentă)
            val hourStr = SimpleDateFormat("HH", Locale.US).format(now) // returnează "00", "01" ... "23"
            val hourKey = todayKey + "_" + hourStr
            val currentHourly = prefs.getInt(hourKey, 0)
            prefs.edit().putInt(hourKey, currentHourly + 1).apply()

            return newTotal // Pentru a-l afișa pe ecranul de overlay
        } catch (e: Exception) {
            return 1
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
        try { return Pair(packageManager.getApplicationIcon(pkg), packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0))?.toString()) } catch (e: Exception) {}
        return Pair(null, null)
    }

    private fun showOverlay(packageName: String, preventedCount: Int) {
        if (overlayShown) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) return

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val scale = resources.displayMetrics.density
        val (iconDrawable, appLabel) = loadAppIconAndLabel(packageName)

        val backdrop = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#AA000000"))
            isClickable = true
            isFocusable = true
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            background = GradientDrawable().apply {
                cornerRadius = 36f * scale
                setColor(Color.parseColor("#22FFFFFF"))
                setStroke((1 * scale).toInt(), Color.parseColor("#33FFFFFF"))
            }
            setPadding((32 * scale).toInt(), (48 * scale).toInt(), (32 * scale).toInt(), (40 * scale).toInt())
            layoutParams = FrameLayout.LayoutParams((320 * scale).toInt(), FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.CENTER)
        }

        iconDrawable?.let {
            card.addView(ImageView(this).apply {
                setImageDrawable(it)
                layoutParams = LinearLayout.LayoutParams((72 * scale).toInt(), (72 * scale).toInt()).apply { bottomMargin = (24 * scale).toInt() }
            })
        }

        card.addView(TextView(this).apply {
            text = "${appLabel ?: "App"} is blocked right now"
            textSize = 22f
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply { bottomMargin = (12 * scale).toInt() }
        })

        if (!currentTaskName.isNullOrBlank()) {
            card.addView(TextView(this).apply {
                text = "You need to focus on:"
                textSize = 14f; setTextColor(Color.parseColor("#AAFFFFFF")); gravity = Gravity.CENTER
            })
            card.addView(TextView(this).apply {
                text = currentTaskName
                textSize = 18f; setTextColor(Color.WHITE); gravity = Gravity.CENTER
                typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.BOLD)
                layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply { topMargin = (4 * scale).toInt(); bottomMargin = (4 * scale).toInt() }
            })

            val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
            val startTimeStr = timeFormat.format(Date(currentTaskStartTimeMs))
            val endTimeStr = timeFormat.format(Date(currentTaskEndTimeMs))

            card.addView(TextView(this).apply {
                text = "$startTimeStr - $endTimeStr"
                textSize = 14f; setTextColor(Color.parseColor("#FFA726")); gravity = Gravity.CENTER
                typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
                layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply { bottomMargin = (24 * scale).toInt() }
            })
        }

        card.addView(TextView(this).apply {
            text = "Distractions prevented today: $preventedCount"
            textSize = 12f
            setTextColor(Color.parseColor("#88FFFFFF"))
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply {
                bottomMargin = (24 * scale).toInt()
            }
        })

        card.addView(Button(this).apply {
            text = "OK"
            setTextColor(Color.BLACK)
            isAllCaps = false
            textSize = 16f
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
            background = GradientDrawable().apply {
                cornerRadius = 24f * scale
                setColor(Color.WHITE)
            }
            layoutParams = LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, (58 * scale).toInt()).apply {
                bottomMargin = (16 * scale).toInt()
            }
            setOnClickListener { removeOverlay() }
        })

        backdrop.addView(card)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED or WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM,
            PixelFormat.TRANSLUCENT
        )

        try {
            windowManager?.addView(backdrop, params)
            overlayView = backdrop; overlayShown = true
            card.alpha = 0f; card.scaleX = 0.85f; card.scaleY = 0.85f
            card.animate().alpha(1f).scaleX(1f).scaleY(1f).setDuration(450).setInterpolator(AccelerateDecelerateInterpolator()).start()
        } catch (e: Exception) { overlayShown = false }
    }

    private fun removeOverlay() {
        if (!overlayShown) return
        try { windowManager?.removeViewImmediate(overlayView) } catch (e: Exception) {}
        overlayView = null; overlayShown = false
    }

    override fun onDestroy() {
        super.onDestroy()
        tickRunnable?.let { handler.removeCallbacks(it) }
        removeOverlay()
    }

    override fun onInterrupt() { removeOverlay() }
}