package com.example.focus_mate

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground service that plays the alarm sound and launches the alarm activity.
 *
 * On Android 10+, starting an activity from a BroadcastReceiver in the background
 * is restricted. A foreground service has the privilege to launch activities,
 * making this the standard approach for alarm apps.
 */
class AlarmForegroundService : Service() {

    companion object {
        const val TAG = "AlarmFgService"
        const val CHANNEL_ID = "alarm_fg_channel"
        const val CHANNEL_NAME = "Alarm Service"
        const val NOTIFICATION_ID = 99999

        fun buildStartIntent(context: Context, id: Int, title: String, body: String,
                             isWeekly: Boolean, weekday: Int, hour: Int, minute: Int): Intent {
            return Intent(context, AlarmForegroundService::class.java).apply {
                putExtra(AlarmReceiver.EXTRA_ALARM_ID, id)
                putExtra(AlarmReceiver.EXTRA_ALARM_TITLE, title)
                putExtra(AlarmReceiver.EXTRA_ALARM_BODY, body)
                putExtra(AlarmReceiver.EXTRA_IS_WEEKLY, isWeekly)
                putExtra(AlarmReceiver.EXTRA_WEEKDAY, weekday)
                putExtra(AlarmReceiver.EXTRA_HOUR, hour)
                putExtra(AlarmReceiver.EXTRA_MINUTE, minute)
            }
        }
    }

    private var ringtone: Ringtone? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        val id = intent.getIntExtra(AlarmReceiver.EXTRA_ALARM_ID, -1)
        val title = intent.getStringExtra(AlarmReceiver.EXTRA_ALARM_TITLE) ?: "Alarm"
        val body = intent.getStringExtra(AlarmReceiver.EXTRA_ALARM_BODY) ?: ""

        Log.d(TAG, "Service started for alarm id=$id")

        // Acquire wake lock to keep CPU running
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "focusmate:alarm_service_wakelock"
        ).apply { acquire(5 * 60_000L) } // 5 minutes max

        // Build the notification required for foreground service
        val notification = buildForegroundNotification(id, title, body, intent)

        // Promote to foreground immediately
        startForeground(NOTIFICATION_ID, notification)

        // Play alarm sound
        playAlarmSound()

        // Launch the activity — foreground services CAN start activities on Android 12+
        launchAlarmActivity(intent)

        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Active alarm notification"
                setBypassDnd(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildForegroundNotification(id: Int, title: String, body: String, intent: Intent): Notification {
        val tapIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(AlarmReceiver.EXTRA_ALARM_ID, id)
            putExtra(AlarmReceiver.EXTRA_ALARM_TITLE, title)
            putExtra(AlarmReceiver.EXTRA_ALARM_BODY, body)
            putExtra(AlarmReceiver.EXTRA_IS_WEEKLY, intent.getBooleanExtra(AlarmReceiver.EXTRA_IS_WEEKLY, false))
            putExtra(AlarmReceiver.EXTRA_WEEKDAY, intent.getIntExtra(AlarmReceiver.EXTRA_WEEKDAY, -1))
            putExtra(AlarmReceiver.EXTRA_HOUR, intent.getIntExtra(AlarmReceiver.EXTRA_HOUR, -1))
            putExtra(AlarmReceiver.EXTRA_MINUTE, intent.getIntExtra(AlarmReceiver.EXTRA_MINUTE, -1))
            action = "com.example.focus_mate.ALARM_FIRED"
        }

        val pendingIntent = PendingIntent.getActivity(
            this, id, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setFullScreenIntent(pendingIntent, true)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(pendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }

    private fun playAlarmSound() {
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val r = RingtoneManager.getRingtone(this, uri)
            if (r != null) {
                r.audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    r.isLooping = true
                }
                r.play()
                ringtone = r
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to play alarm sound: ${e.message}")
        }
    }

    private fun launchAlarmActivity(originalIntent: Intent) {
        try {
            val launchIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(AlarmReceiver.EXTRA_ALARM_ID,
                    originalIntent.getIntExtra(AlarmReceiver.EXTRA_ALARM_ID, -1))
                putExtra(AlarmReceiver.EXTRA_ALARM_TITLE,
                    originalIntent.getStringExtra(AlarmReceiver.EXTRA_ALARM_TITLE) ?: "Alarm")
                putExtra(AlarmReceiver.EXTRA_ALARM_BODY,
                    originalIntent.getStringExtra(AlarmReceiver.EXTRA_ALARM_BODY) ?: "")
                putExtra(AlarmReceiver.EXTRA_IS_WEEKLY,
                    originalIntent.getBooleanExtra(AlarmReceiver.EXTRA_IS_WEEKLY, false))
                putExtra(AlarmReceiver.EXTRA_WEEKDAY,
                    originalIntent.getIntExtra(AlarmReceiver.EXTRA_WEEKDAY, -1))
                putExtra(AlarmReceiver.EXTRA_HOUR,
                    originalIntent.getIntExtra(AlarmReceiver.EXTRA_HOUR, -1))
                putExtra(AlarmReceiver.EXTRA_MINUTE,
                    originalIntent.getIntExtra(AlarmReceiver.EXTRA_MINUTE, -1))
                action = "com.example.focus_mate.ALARM_FIRED"
            }
            startActivity(launchIntent)
            Log.d(TAG, "Activity launched from foreground service")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch activity: ${e.message}")
            // Fallback: the fullScreenIntent on the notification will handle it
        }
    }

    fun stopAlarm() {
        ringtone?.let {
            if (it.isPlaying) it.stop()
            ringtone = null
        }
        wakeLock?.let {
            if (it.isHeld) it.release()
            wakeLock = null
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        ringtone?.let { if (it.isPlaying) it.stop() }
        wakeLock?.let { if (it.isHeld) it.release() }
        super.onDestroy()
    }
}
