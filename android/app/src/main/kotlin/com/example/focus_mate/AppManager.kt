package com.example.focus_mate

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.util.Base64
import java.io.ByteArrayOutputStream
import android.util.Log

class AppManager(private val context: Context) {

    /**
     * Returnează TOATE aplicațiile instalate (inclusiv sistem)
     * în format List<Map<String, Any>>
     */
    fun getAllInstalledApps(): List<Map<String, Any>> {
        val pm = context.packageManager
        val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        Log.e("APPS_DEBUG", "TOTAL APPS = ${packages.size}")

        packages.forEach {
            Log.e("APPS_DEBUG", "APP = ${it.packageName}")
        }

        return packages.mapNotNull { appInfo ->
            try {
                val packageName = appInfo.packageName
                val appName = pm.getApplicationLabel(appInfo).toString()
                val isSystemApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

                // Obține icon-ul
                val icon = try {
                    pm.getApplicationIcon(packageName)
                } catch (e: Exception) {
                    null
                }

                // Convertește icon-ul în Base64 (dacă există)
                val iconBase64 = icon?.let { drawableToBase64(it) }

                mapOf(
                    "packageName" to packageName,
                    "appName" to appName,
                    "isSystemApp" to isSystemApp,
                    "iconBase64" to (iconBase64 ?: "")
                )
            } catch (e: Exception) {
                null
            }
        }.sortedBy { it["appName"] as String }
    }

    /**
     * Returnează doar aplicațiile cu launcher intent (cele care apar în drawer)
     */
    fun getUserApps(): List<Map<String, Any>> {
        val pm = context.packageManager
        val mainIntent = android.content.Intent(android.content.Intent.ACTION_MAIN, null)
        mainIntent.addCategory(android.content.Intent.CATEGORY_LAUNCHER)

        val launchableApps = pm.queryIntentActivities(mainIntent, 0)

        return launchableApps.mapNotNull { resolveInfo ->
            try {
                val packageName = resolveInfo.activityInfo.packageName
                val appInfo = pm.getApplicationInfo(packageName, 0)
                val appName = pm.getApplicationLabel(appInfo).toString()
                val isSystemApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

                // Obține icon-ul
                val icon = try {
                    pm.getApplicationIcon(packageName)
                } catch (e: Exception) {
                    null
                }

                // Convertește icon-ul în Base64
                val iconBase64 = icon?.let { drawableToBase64(it) }

                mapOf(
                    "packageName" to packageName,
                    "appName" to appName,
                    "isSystemApp" to isSystemApp,
                    "iconBase64" to (iconBase64 ?: "")
                )
            } catch (e: Exception) {
                null
            }
        }.distinctBy { it["packageName"] as String } // Elimină duplicatele
         .sortedBy { it["appName"] as String }
    }

    /**
     * Returnează doar aplicațiile user (non-sistem) cu launcher intent
     */
    fun getNonSystemApps(): List<Map<String, Any>> {
        return getUserApps().filter {
            !(it["isSystemApp"] as Boolean)
        }
    }

    /**
     * Convertește un Drawable în Base64 string
     */
    private fun drawableToBase64(drawable: Drawable): String? {
        return try {
            val bitmap = if (drawable is BitmapDrawable) {
                drawable.bitmap
            } else {
                val bitmap = Bitmap.createBitmap(
                    drawable.intrinsicWidth.coerceAtLeast(1),
                    drawable.intrinsicHeight.coerceAtLeast(1),
                    Bitmap.Config.ARGB_8888
                )
                val canvas = Canvas(bitmap)
                drawable.setBounds(0, 0, canvas.width, canvas.height)
                drawable.draw(canvas)
                bitmap
            }

            val outputStream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
            val byteArray = outputStream.toByteArray()
            Base64.encodeToString(byteArray, Base64.NO_WRAP)
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Verifică dacă o aplicație este instalată
     */
    fun isAppInstalled(packageName: String): Boolean {
        return try {
            context.packageManager.getApplicationInfo(packageName, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    /**
     * Obține numele unei aplicații după packageName
     */
    fun getAppName(packageName: String): String? {
        return try {
            val pm = context.packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Obține icon-ul unei aplicații în Base64
     */
    fun getAppIcon(packageName: String): String? {
        return try {
            val pm = context.packageManager
            val icon = pm.getApplicationIcon(packageName)
            drawableToBase64(icon)
        } catch (e: Exception) {
            null
        }
    }
}

