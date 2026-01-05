package com.example.focus_mate

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.content.SharedPreferences
import android.provider.Settings
import android.text.TextUtils
import android.widget.Toast
import android.accessibilityservice.AccessibilityService

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

                    myReceiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context?, intent: Intent?) {
                            val pkg = intent?.getStringExtra("package")
                            pkg?.let { eventSink?.success(it) }
                        }
                    }

                    val filter = IntentFilter("com.block_app.ACTION_SHOW_OVERLAY")

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        registerReceiver(myReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
                    } else {
                        registerReceiver(myReceiver, filter)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    myReceiver?.let {
                        unregisterReceiver(it)
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
                        if (apps != null) {
                            saveBlockedApps(apps)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "Apps list is null", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to update blocked apps: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ✅ MethodChannel pentru verificare Accessibility Service
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
    }

    private fun saveBlockedApps(apps: List<String>) {
        val prefs: SharedPreferences = getSharedPreferences("focus_mate_prefs", Context.MODE_PRIVATE)
        val editor = prefs.edit()
        editor.putStringSet("blocked_apps", apps.toSet())
        editor.apply()

        // Notifică serviciul de accessibility despre schimbare
        val intent = Intent("com.example.focus_mate.UPDATE_BLOCKED_APPS")
        intent.putStringArrayListExtra("apps", ArrayList(apps))
        sendBroadcast(intent)
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

    // ✅ Helper pentru verificare Accessibility Service
    private fun isAccessibilityServiceEnabled(serviceClass: Class<out AccessibilityService>): Boolean {
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        )
        val serviceId = "${packageName}/${serviceClass.name}"
        return enabledServices?.contains(serviceId) == true
    }

    // ✅ Deschide setările de Accessibility
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

