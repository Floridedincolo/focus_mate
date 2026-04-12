package com.example.focus_mate

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * BroadcastReceiver triggered by AlarmManager when a scheduled alarm fires.
 * Starts [AlarmForegroundService] which has the privilege to launch activities
 * even from the background on Android 10+/12+.
 */
class AlarmReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "AlarmReceiver"
        const val EXTRA_ALARM_ID = "alarm_id"
        const val EXTRA_ALARM_TITLE = "alarm_title"
        const val EXTRA_ALARM_BODY = "alarm_body"
        const val EXTRA_IS_WEEKLY = "alarm_is_weekly"
        const val EXTRA_WEEKDAY = "alarm_weekday"
        const val EXTRA_HOUR = "alarm_hour"
        const val EXTRA_MINUTE = "alarm_minute"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Alarm fired!")

        val id = intent.getIntExtra(EXTRA_ALARM_ID, -1)
        val title = intent.getStringExtra(EXTRA_ALARM_TITLE) ?: "Alarm"
        val body = intent.getStringExtra(EXTRA_ALARM_BODY) ?: ""
        val isWeekly = intent.getBooleanExtra(EXTRA_IS_WEEKLY, false)
        val weekday = intent.getIntExtra(EXTRA_WEEKDAY, -1)
        val hour = intent.getIntExtra(EXTRA_HOUR, -1)
        val minute = intent.getIntExtra(EXTRA_MINUTE, -1)

        val serviceIntent = AlarmForegroundService.buildStartIntent(
            context, id, title, body, isWeekly, weekday, hour, minute
        )

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.d(TAG, "Foreground service started for alarm id=$id")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start foreground service: ${e.message}")
            // Last resort: try to launch activity directly
            try {
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra(EXTRA_ALARM_ID, id)
                    putExtra(EXTRA_ALARM_TITLE, title)
                    putExtra(EXTRA_ALARM_BODY, body)
                    putExtra(EXTRA_IS_WEEKLY, isWeekly)
                    putExtra(EXTRA_WEEKDAY, weekday)
                    putExtra(EXTRA_HOUR, hour)
                    putExtra(EXTRA_MINUTE, minute)
                    action = "com.example.focus_mate.ALARM_FIRED"
                }
                context.startActivity(launchIntent)
            } catch (e2: Exception) {
                Log.e(TAG, "Fallback activity launch also failed: ${e2.message}")
            }
        }
    }
}
