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
import java.util.Calendar

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
                        val data = getUsageStatsData(days)
                        result.success(data)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to get usage stats: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getUsageStatsData(days: Int = 1): HashMap<String, Any> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        val calendar = Calendar.getInstance()
        val endTime = calendar.timeInMillis
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        // Go back (days - 1) more days for weekly view
        if (days > 1) {
            calendar.add(Calendar.DAY_OF_YEAR, -(days - 1))
        }
        val startTime = calendar.timeInMillis

        // --- Per-app usage from queryUsageStats ---
        val usageStatsList = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY, startTime, endTime
        )

        val appUsageMap = HashMap<String, Long>() // packageName -> totalTimeMs
        for (stat in usageStatsList) {
            val time = stat.totalTimeInForeground
            if (time > 0) {
                appUsageMap[stat.packageName] = (appUsageMap[stat.packageName] ?: 0L) + time
            }
        }

        // --- Hourly distribution from queryEvents ---
        // For weekly view, we average hours across days
        val hourlyMs = LongArray(24) { 0L }
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
                        distributeTimeToHours(hourlyMs, lastForegroundTime, event.timeStamp, startTime)
                        lastForegroundTime = 0L
                    }
                }
            }
        }
        // If an app is still in foreground, count time until now
        if (lastForegroundTime > 0) {
            distributeTimeToHours(hourlyMs, lastForegroundTime, endTime, startTime)
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

        val result = HashMap<String, Any>()
        result["totalScreenTimeMinutes"] = totalMinutes
        result["hourlyUsage"] = hourlyMinutes
        result["topApps"] = topApps
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
        val editor = prefs.edit()
        editor.putStringSet("blocked_apps", apps.toSet())
        editor.putBoolean("is_whitelist", isWhitelist)
        editor.apply()

        // Notifică serviciul de accessibility despre schimbare (broadcast EXPLICIT pentru Android 12+)
        val intent = Intent("com.example.focus_mate.UPDATE_BLOCKED_APPS")
        intent.setPackage(packageName) //  Face broadcast-ul EXPLICIT
        intent.putStringArrayListExtra("apps", ArrayList(apps))
        sendBroadcast(intent)
        Log.d("MainActivity", "📤 Sent UPDATE_BLOCKED_APPS broadcast with ${apps.size} apps")

        // Dacă Flutter e conectat la EventChannel, trimitem direct update-ul pentru a fi instant
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
