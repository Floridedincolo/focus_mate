package com.example.focus_mate

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.content.SharedPreferences
import android.provider.Settings
import android.text.TextUtils
import android.widget.Toast
import android.accessibilityservice.AccessibilityService
import android.app.usage.UsageStatsManager
import android.app.usage.UsageEvents
import android.app.AppOpsManager
import android.os.Process
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val EVENT_CHANNEL = "accessibility_events"
    private val METHOD_CHANNEL = "com.example.focus_mate/blocking"
    private var eventSink: EventChannel.EventSink? = null
    private var myReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // EventChannel pentru evenimente de accessibility
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events

                    // Trimite starea inițială imediat
                    val enabled = isAccessibilityServiceEnabled(AppBlockService::class.java)
                    val canDraw = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this@MainActivity)
                    } else {
                        true
                    }
                    val blocked = getBlockedApps().toList()

                    val payload = HashMap<String, Any?>()
                    payload["event"] = "initialState"
                    payload["accessibilityEnabled"] = enabled
                    payload["canDrawOverlays"] = canDraw
                    payload["blockedApps"] = blocked
                    events?.success(payload)

                    // Receiver pentru actualizări din serviciul de blocare
                    myReceiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context?, intent: Intent?) {
                            when (intent?.action) {
                                "com.block_app.ACTION_SHOW_OVERLAY" -> {
                                    val pkg = intent.getStringExtra("package")
                                    pkg?.let { eventSink?.success(it) }
                                }
                                "com.example.focus_mate.UPDATE_BLOCKED_APPS" -> {
                                    val apps = intent.getStringArrayListExtra("apps") ?: ArrayList(getBlockedApps())
                                    val updatePayload = HashMap<String, Any?>()
                                    updatePayload["event"] = "blockedAppsUpdated"
                                    updatePayload["blockedApps"] = apps
                                    eventSink?.success(updatePayload)
                                }
                            }
                        }
                    }

                    val filter = IntentFilter().apply {
                        addAction("com.block_app.ACTION_SHOW_OVERLAY")
                        addAction("com.example.focus_mate.UPDATE_BLOCKED_APPS")
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        registerReceiver(myReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
                    } else {
                        registerReceiver(myReceiver, filter)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    myReceiver?.let {
                        try { unregisterReceiver(it) } catch (_: Exception) { }
                        myReceiver = null
                    }
                    eventSink = null
                }
            }
        )

        // MethodChannel pentru gestionarea aplicațiilor
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.focus_mate/apps").setMethodCallHandler { call, result ->
            when (call.method) {
                "getAllInstalledApps" -> {
                    try {
                        val appManager = AppManager(this)
                        val apps = appManager.getAllInstalledApps()
                        result.success(apps)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to get installed apps: ${e.message}", null)
                    }
                }
                "getUserApps" -> {
                    try {
                        val appManager = AppManager(this)
                        val apps = appManager.getUserApps()
                        result.success(apps)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to get user apps: ${e.message}", null)
                    }
                }
                "getAppName" -> {
                    try {
                        val packageName = call.argument<String>("packageName")
                        if (packageName != null) {
                            val appManager = AppManager(this)
                            val appName = appManager.getAppName(packageName)
                            result.success(appName)
                        } else {
                            result.error("INVALID_ARGUMENT", "Package name is null", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to get app name: ${e.message}", null)
                    }
                }
                "getAppIcon" -> {
                    try {
                        val packageName = call.argument<String>("packageName")
                        if (packageName != null) {
                            val appManager = AppManager(this)
                            val iconBase64 = appManager.getAppIcon(packageName)
                            result.success(iconBase64)
                        } else {
                            result.error("INVALID_ARGUMENT", "Package name is null", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to get app icon: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // MethodChannel pentru actualizare lista aplicații blocate
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.block_app/blocker").setMethodCallHandler { call, result ->
            when (call.method) {
                "addBlockedApp" -> {
                    try {
                        val pkg = call.argument<String>("package")
                        if (pkg != null) {
                            addBlockedApp(pkg)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "Package is null", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to add blocked app: ${e.message}", null)
                    }
                }
                "removeBlockedApp" -> {
                    try {
                        val pkg = call.argument<String>("package")
                        if (pkg != null) {
                            removeBlockedApp(pkg)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "Package is null", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to remove blocked app: ${e.message}", null)
                    }
                }
                "clearBlockList" -> {
                    try {
                        clearBlockedApps()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to clear block list: ${e.message}", null)
                    }
                }
                "setBlockedApps" -> {
                    try {
                        val packages = call.argument<List<String>>("packages")
                        if (packages != null) {
                            setBlockedApps(packages)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "Packages list is null", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to set blocked apps: ${e.message}", null)
                    }
                }
                "updateBlockedApps" -> {
                    try {
                        val apps = call.argument<List<String>>("apps")
                        val isWhitelist = call.argument<Boolean>("isWhitelist") ?: false
                        if (apps != null) {
                            saveBlockedApps(apps, isWhitelist)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "Apps list is null", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to update blocked apps: ${e.message}", null)
                    }
                }
                "setCurrentTaskName" -> {
                    try {
                        val taskName = call.argument<String?>("taskName")
                        saveCurrentTaskName(taskName)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to set current task name: ${e.message}", null)
                    }
                }
                "clearCurrentTaskName" -> {
                    try {
                        saveCurrentTaskName(null)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to clear current task name: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        //  MethodChannel pentru verificare Accessibility Service
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focus_mate/accessibility").setMethodCallHandler { call, result ->
            when(call.method) {
                "checkAccessibility" -> {
                    val enabled = isAccessibilityServiceEnabled(AppBlockService::class.java)
                    result.success(enabled)
                }
                "promptAccessibility" -> {
                    promptEnableAccessibility()
                    result.success(null)
                }
                "canDrawOverlays" -> {
                    val canDraw = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(canDraw)
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            android.net.Uri.parse("package:$packageName")
                        )
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        Toast.makeText(
                            this,
                            "Activează 'Display over other apps' pentru FocusMate",
                            Toast.LENGTH_LONG
                        ).show()
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // MethodChannel pentru Usage Stats
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.focus_mate/usage_stats").setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsagePermission" -> {
                    try {
                        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
                        val mode = appOps.checkOpNoThrow(
                            AppOpsManager.OPSTR_GET_USAGE_STATS,
                            Process.myUid(),
                            packageName
                        )
                        result.success(mode == AppOpsManager.MODE_ALLOWED)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "requestUsagePermission" -> {
                    try {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                    } catch (_: Exception) { }
                    result.success(null)
                }
                "getUsageStats" -> {
                    try {
                        val days = call.argument<Int>("days") ?: 1
                        val dayOffset = call.argument<Int>("dayOffset") ?: 0
                        val data = getUsageStatsData(days, dayOffset)
                        result.success(data)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to get usage stats: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getUsageStatsData(days: Int = 1, dayOffset: Int = 0): HashMap<String, Any> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        val calendar = Calendar.getInstance()
        // Apply day offset (0 = today, -1 = yesterday, etc.)
        if (dayOffset != 0) {
            calendar.add(Calendar.DAY_OF_YEAR, dayOffset)
        }

        // End time: for today use now, for past days use midnight of next day
        val endTime: Long
        if (dayOffset < 0) {
            val endCal = Calendar.getInstance()
            endCal.add(Calendar.DAY_OF_YEAR, dayOffset + 1)
            endCal.set(Calendar.HOUR_OF_DAY, 0)
            endCal.set(Calendar.MINUTE, 0)
            endCal.set(Calendar.SECOND, 0)
            endCal.set(Calendar.MILLISECOND, 0)
            endTime = endCal.timeInMillis
        } else {
            endTime = calendar.timeInMillis
        }

        // Start time: midnight of the target day (go back days-1 more for weekly)
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        if (days > 1) {
            calendar.add(Calendar.DAY_OF_YEAR, -(days - 1))
        }
        val startTime = calendar.timeInMillis

        // --- Per-app usage AND hourly distribution from queryEvents ---
        // Using queryEvents instead of queryUsageStats avoids the bug where
        // INTERVAL_DAILY buckets leak data from adjacent days (e.g., at 1 AM
        // you'd see yesterday's full 13h of screen time).
        val hourlyMs = LongArray(24) { 0L }
        val appUsageMap = HashMap<String, Long>() // packageName -> totalTimeMs
        val hourlyAppMs = HashMap<String, LongArray>() // packageName -> ms per hour (24)
        // Per-day tracking for weekly/monthly stacked bar charts
        val dailyMs = LongArray(days) { 0L }
        val dailyAppMs = HashMap<String, LongArray>() // packageName -> ms per day
        val events = usageStatsManager.queryEvents(startTime, endTime)
        val event = UsageEvents.Event()
        var lastForegroundTime = 0L
        var lastForegroundPkg = ""

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    lastForegroundTime = event.timeStamp
                    lastForegroundPkg = event.packageName
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    if (lastForegroundTime > 0 && event.packageName == lastForegroundPkg) {
                        val duration = event.timeStamp - lastForegroundTime
                        distributeTimeToHours(hourlyMs, lastForegroundTime, event.timeStamp, startTime)
                        val appHours = hourlyAppMs.getOrPut(lastForegroundPkg) { LongArray(24) { 0L } }
                        distributeTimeToHours(appHours, lastForegroundTime, event.timeStamp, startTime)
                        // Daily distribution
                        distributeTimeToDays(dailyMs, lastForegroundTime, event.timeStamp, startTime, days)
                        val appDays = dailyAppMs.getOrPut(lastForegroundPkg) { LongArray(days) { 0L } }
                        distributeTimeToDays(appDays, lastForegroundTime, event.timeStamp, startTime, days)
                        appUsageMap[lastForegroundPkg] = (appUsageMap[lastForegroundPkg] ?: 0L) + duration
                        lastForegroundTime = 0L
                    }
                }
            }
        }
        // If an app is still in foreground, count time until now
        if (lastForegroundTime > 0) {
            val duration = endTime - lastForegroundTime
            distributeTimeToHours(hourlyMs, lastForegroundTime, endTime, startTime)
            val appHours = hourlyAppMs.getOrPut(lastForegroundPkg) { LongArray(24) { 0L } }
            distributeTimeToHours(appHours, lastForegroundTime, endTime, startTime)
            distributeTimeToDays(dailyMs, lastForegroundTime, endTime, startTime, days)
            val appDays = dailyAppMs.getOrPut(lastForegroundPkg) { LongArray(days) { 0L } }
            distributeTimeToDays(appDays, lastForegroundTime, endTime, startTime, days)
            appUsageMap[lastForegroundPkg] = (appUsageMap[lastForegroundPkg] ?: 0L) + duration
        }

        // For weekly view, average the hourly data
        val divisor = if (days > 1) days else 1
        val hourlyMinutes = hourlyMs.map { it / 60000 / divisor }

        // --- Build top apps list (with icons) ---
        val appManager = AppManager(this)
        val topApps = appUsageMap.entries
            .sortedByDescending { it.value }
            .take(15)
            .map { entry ->
                val appName = try {
                    appManager.getAppName(entry.key) ?: entry.key
                } catch (_: Exception) { entry.key }
                val iconBase64 = try {
                    appManager.getAppIcon(entry.key) ?: ""
                } catch (_: Exception) { "" }
                val minutes = entry.value / 60000
                hashMapOf<String, Any>(
                    "packageName" to entry.key,
                    "appName" to appName,
                    "usageMinutes" to minutes,
                    "iconBase64" to iconBase64
                )
            }

        val totalMinutes = appUsageMap.values.sum() / 60000

        // ── Read focus time and prevented distractions from SharedPreferences ──
        val focusPrefs = getSharedPreferences("focus_mate_prefs", Context.MODE_PRIVATE)
        val dayFmt = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        var totalFocusMinutes = 0L
        var totalPrevented = 0

        val cal2 = Calendar.getInstance()
        for (d in 0 until days) {
            val dateKey = dayFmt.format(cal2.time)
            totalFocusMinutes += focusPrefs.getLong("focus_minutes_$dateKey", 0L)
            totalPrevented += focusPrefs.getInt(
                AppBlockService.PREF_PREVENTED_PREFIX + dateKey, 0
            )
            cal2.add(Calendar.DAY_OF_YEAR, -1)
        }

        // If a focus session is currently active, add elapsed time
        val sessionStart = focusPrefs.getLong("focus_session_start", 0L)
        if (sessionStart > 0) {
            val liveMin = (System.currentTimeMillis() - sessionStart) / 60000
            totalFocusMinutes += liveMin
        }

        // Build per-app per-hour minutes map for stacked bar chart
        val hourlyAppUsage = HashMap<String, List<Long>>()
        for ((pkg, hours) in hourlyAppMs) {
            hourlyAppUsage[pkg] = hours.map { it / 60000 / divisor }
        }

        // Build per-day minutes and per-app per-day minutes for weekly/monthly charts
        val dailyMinutes = dailyMs.map { it / 60000 }
        val dailyAppUsage = HashMap<String, List<Long>>()
        for ((pkg, dayArr) in dailyAppMs) {
            dailyAppUsage[pkg] = dayArr.map { it / 60000 }
        }

        // Compute weekday index (0=Mon) for the start date so Flutter knows labels
        val startCal = Calendar.getInstance()
        startCal.timeInMillis = startTime
        val startWeekday = (startCal.get(Calendar.DAY_OF_WEEK) + 5) % 7 // Mon=0..Sun=6

        val result = HashMap<String, Any>()
        result["totalScreenTimeMinutes"] = totalMinutes
        result["hourlyUsage"] = hourlyMinutes
        result["hourlyAppUsage"] = hourlyAppUsage
        result["dailyUsage"] = dailyMinutes
        result["dailyAppUsage"] = dailyAppUsage
        result["startWeekday"] = startWeekday
        result["topApps"] = topApps
        result["focusTimeMinutes"] = totalFocusMinutes
        result["preventedDistractions"] = totalPrevented
        return result
    }

    private fun distributeTimeToHours(hourlyMs: LongArray, start: Long, end: Long, dayStart: Long) {
        val cal = Calendar.getInstance()
        var current = start
        while (current < end) {
            cal.timeInMillis = current
            val hour = cal.get(Calendar.HOUR_OF_DAY)
            // End of this hour
            cal.set(Calendar.MINUTE, 59)
            cal.set(Calendar.SECOND, 59)
            cal.set(Calendar.MILLISECOND, 999)
            val hourEnd = minOf(cal.timeInMillis + 1, end)
            val duration = hourEnd - current
            if (hour in 0..23) {
                hourlyMs[hour] += duration
            }
            current = hourEnd
        }
    }

    private fun distributeTimeToDays(dailyMs: LongArray, start: Long, end: Long, periodStart: Long, days: Int) {
        val msPerDay = 24L * 60 * 60 * 1000
        var current = start
        while (current < end) {
            val dayIdx = ((current - periodStart) / msPerDay).toInt().coerceIn(0, days - 1)
            val dayEnd = periodStart + (dayIdx + 1) * msPerDay
            val segmentEnd = minOf(dayEnd, end)
            val duration = segmentEnd - current
            dailyMs[dayIdx] += duration
            current = segmentEnd
        }
    }

    private fun saveCurrentTaskName(taskName: String?) {
        val prefs: SharedPreferences = getSharedPreferences("focus_mate_prefs", Context.MODE_PRIVATE)
        val editor = prefs.edit()
        if (taskName != null) {
            editor.putString("current_task_name", taskName)
        } else {
            editor.remove("current_task_name")
        }
        editor.apply()
        Log.d("MainActivity", "📤 Current task name updated: $taskName")
    }

    private fun saveBlockedApps(apps: List<String>, isWhitelist: Boolean = false) {
        val prefs: SharedPreferences = getSharedPreferences("focus_mate_prefs", Context.MODE_PRIVATE)

        // ── Focus session tracking (single editor to avoid race conditions) ──
        val hadBlocking = (prefs.getStringSet("blocked_apps", emptySet())?.isNotEmpty() == true)
        val hasBlocking = apps.isNotEmpty()

        val editor = prefs.edit()

        // Always save the blocked apps list first
        editor.putStringSet("blocked_apps", apps.toSet())
        editor.putBoolean("is_whitelist", isWhitelist)

        // Track focus session transitions
        try {
            if (!hadBlocking && hasBlocking) {
                editor.putLong("focus_session_start", System.currentTimeMillis())
                Log.d("MainActivity", "🟢 Focus session STARTED")
            } else if (hadBlocking && !hasBlocking) {
                val sessionStart = prefs.getLong("focus_session_start", 0L)
                if (sessionStart > 0) {
                    val elapsedMs = System.currentTimeMillis() - sessionStart
                    val elapsedMin = elapsedMs / 60000
                    val dayFmt = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                    val todayKey = dayFmt.format(Date())
                    val focusKey = "focus_minutes_$todayKey"
                    val prevMin = prefs.getLong(focusKey, 0L)
                    editor.putLong(focusKey, prevMin + elapsedMin)
                    editor.remove("focus_session_start")
                    Log.d("MainActivity", "🔴 Focus session ENDED — +${elapsedMin}min (total today: ${prevMin + elapsedMin}min)")
                }
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Focus tracking error (non-fatal): ${e.message}")
        }

        editor.apply()

        // Notify the accessibility service via explicit broadcast (Android 12+)
        val intent = Intent("com.example.focus_mate.UPDATE_BLOCKED_APPS")
        intent.setPackage(packageName)
        intent.putStringArrayListExtra("apps", ArrayList(apps))
        sendBroadcast(intent)
        Log.d("MainActivity", "📤 Sent UPDATE_BLOCKED_APPS broadcast with ${apps.size} apps")

        // If Flutter is connected to EventChannel, send an instant update
        eventSink?.let { sink ->
            val updatePayload = HashMap<String, Any?>()
            updatePayload["event"] = "blockedAppsUpdated"
            updatePayload["blockedApps"] = ArrayList(apps)
            try { sink.success(updatePayload) } catch (_: Exception) { }
        }
    }

    private fun getBlockedApps(): Set<String> {
        val prefs: SharedPreferences = getSharedPreferences("focus_mate_prefs", Context.MODE_PRIVATE)
        return prefs.getStringSet("blocked_apps", emptySet()) ?: emptySet()
    }

    private fun addBlockedApp(packageName: String) {
        val currentApps = getBlockedApps().toMutableSet()
        currentApps.add(packageName)
        saveBlockedApps(currentApps.toList())
    }

    private fun removeBlockedApp(packageName: String) {
        val currentApps = getBlockedApps().toMutableSet()
        currentApps.remove(packageName)
        saveBlockedApps(currentApps.toList())
    }

    private fun clearBlockedApps() {
        saveBlockedApps(emptyList())
    }

    private fun setBlockedApps(packages: List<String>) {
        saveBlockedApps(packages)
    }

    //  Helper pentru verificare Accessibility Service
    private fun isAccessibilityServiceEnabled(serviceClass: Class<out AccessibilityService>): Boolean {
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        )
        val serviceId = "${packageName}/${serviceClass.name}"
        return enabledServices?.contains(serviceId) == true
    }

    //  Deschide setările de Accessibility
    private fun promptEnableAccessibility() {
        Toast.makeText(
            this,
            "Vă rugăm să activați FocusMate Accessibility pentru a bloca aplicațiile",
            Toast.LENGTH_LONG
        ).show()
        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        })
    }
}
