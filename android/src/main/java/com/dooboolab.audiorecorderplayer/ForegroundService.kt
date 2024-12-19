package com.dooboolab.audiorecorderplayer;

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat


class ForegroundService : Service() {

    private val NOTIFICATION_ID = 1
    private val CHANNEL_ID = "111"

    override fun onBind(intent: Intent): IBinder? {
        return null
    }

    override fun onCreate() {
        super.onCreate()
        // Initialize and register the broadcast receiver to listen for app kill events

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val filter = IntentFilter(Intent.ACTION_CLOSE_SYSTEM_DIALOGS)
        }
    }

    override fun onStartCommand(intent: Intent, flags: Int, startId: Int): Int {
        // Start the foreground service with the notification
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, createNotification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        }else{
            startForeground(NOTIFICATION_ID, createNotification())
        }

        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent) {
        // Stop the foreground service when the app is removed from recent tasks
        stopForeground(STOP_FOREGROUND_REMOVE)  // Correct method call for Android 14
        stopSelf()

        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        // Ensure that the service is stopped when it's destroyed
        stopForeground(STOP_FOREGROUND_REMOVE)  // Correct method call for Android 14

        super.onDestroy()
    }

    private fun createNotification(): Notification {
        val notificationIntent: Intent? =
            packageManager.getLaunchIntentForPackage(packageName)

        val pendingIntent = PendingIntent.getActivity(this, 0, notificationIntent, PendingIntent.FLAG_MUTABLE)

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("DentScribe")
            .setContentText("DentScribe recording is currently in progress")
            .setSmallIcon(android.R.drawable.ic_menu_save)
            .setContentIntent(pendingIntent)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, "Recording Notifications", importance)
            channel.description = "Notifications for ongoing recordings"
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }

        return builder.build()
    }
}

