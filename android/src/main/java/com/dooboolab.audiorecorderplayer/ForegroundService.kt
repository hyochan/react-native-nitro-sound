package com.dooboolab.audiorecorderplayer;

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.PendingIntent.FLAG_MUTABLE
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat


class ForegroundService : Service() {

    private val NOTIFICATION_ID = 1

    override fun onBind(intent: Intent): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent, flags: Int, startId: Int): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, createNotification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE);
        }else{
            startForeground(NOTIFICATION_ID, createNotification());
        }

        return START_STICKY
    }

    private fun createNotification(): Notification {
        val notificationIntent: Intent? =
            RNAudioRecorderPlayerModule.reactApplicationContex!!.packageManager.getLaunchIntentForPackage(
                RNAudioRecorderPlayerModule.reactApplicationContex!!.packageName)

        val pendingIntent = PendingIntent.getActivity(this, 0, notificationIntent, FLAG_MUTABLE)

        val builder = NotificationCompat.Builder(this, "111") // Replace with your notification channel ID
            .setContentTitle("Dentcribe")
            .setContentText("Dentscribe recording is currently in progress")
            .setSmallIcon(android.R.drawable.ic_menu_save) // Replace with your notification icon
            .setContentIntent(pendingIntent)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder.setChannelId("111") // Replace with your notification channel ID
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel =
                NotificationChannel("111", "taskTitle", importance)
            channel.description = "taskDesc"
            val notificationManager = getSystemService(
                NotificationManager::class.java
            )
            notificationManager.createNotificationChannel(channel)
        }

        return builder.build()
    }
}

