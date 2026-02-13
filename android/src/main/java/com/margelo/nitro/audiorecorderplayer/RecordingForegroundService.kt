package com.margelo.nitro.audiorecorderplayer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.MediaRecorder
import android.os.Binder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import java.io.File
import java.util.Timer
import java.util.TimerTask

/**
 * Foreground Service that owns and manages WavRecorder (AudioRecord-based)
 * Required for Android 9+ to record audio in background
 * 
 * Uses WAV format for crash-resilient recording:
 * - WAV files are always playable even if recording is interrupted
 * - Data is written continuously, no buffering issues
 * - Header can be repaired/updated after crash
 */
class RecordingForegroundService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private var wavRecorder: WavRecorder? = null
    private var recordTimer: Timer? = null
    
    // Recording state
    private var currentRecordingPath: String? = null
    private var meteringEnabled: Boolean = false
    
    // Metering
    private var lastMeteringUpdateTime = 0L
    private var lastMeteringValue = SILENCE_THRESHOLD_DB
    
    // Callback for recording updates
    var onRecordingUpdate: ((isRecording: Boolean, currentPosition: Double, metering: Double?) -> Unit)? = null
    
    private val handler = Handler(Looper.getMainLooper())
    private val binder = RecordingBinder()
    
    companion object {
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "recording_channel"
        private const val CHANNEL_NAME = "Audio Recording"
        private const val WAKE_LOCK_TAG = "RecordingForegroundService::WakeLock"
        
        // Audio constants
        private const val SILENCE_THRESHOLD_DB = -160.0
        private const val METERING_UPDATE_INTERVAL_MS = 100L
        private const val METERING_DISABLED_VALUE = 0.0
        
        // Wake lock timeout: 30 minutes, renewed periodically while recording
        private const val WAKE_LOCK_TIMEOUT_MS = 30 * 60 * 1000L
        
        private var instance: RecordingForegroundService? = null
        
        fun getInstance(): RecordingForegroundService? = instance
        
        fun start(context: Context) {
            val intent = Intent(context, RecordingForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun stop(context: Context) {
            instance?.stopRecordingInternal()
            val intent = Intent(context, RecordingForegroundService::class.java)
            context.stopService(intent)
        }
    }
    
    inner class RecordingBinder : Binder() {
        fun getService(): RecordingForegroundService = this@RecordingForegroundService
    }
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, createNotification())
        // Use START_NOT_STICKY: if the system kills the process, don't restart
        // the service automatically. This prevents a zombie foreground notification
        // with no active recording and no way to stop it from JS.
        return START_NOT_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder {
        return binder
    }
    
    override fun onDestroy() {
        stopRecordingInternal()
        instance = null
        super.onDestroy()
    }
    
    /**
     * Called when user swipes away the app from recents.
     * This ensures the audio file is properly finalized so it can be opened later.
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        // Finalize the audio file before the app is killed
        finalizeRecordingOnKill()
        super.onTaskRemoved(rootIntent)
        // Stop the service after finalizing
        stopSelf()
    }
    
    /**
     * Safely finalize the recording when app is being killed.
     * WAV format ensures the audio file is always playable - just need to update header.
     */
    private fun finalizeRecordingOnKill() {
        try {
            Logger.d("[ForegroundService] Finalizing WAV recording on app kill...")
            
            stopRecordTimer()
            
            // WavRecorder handles its own finalization and header update
            wavRecorder?.finalizeOnKill()
            wavRecorder = null
            
            // Release wake lock
            releaseWakeLock()
            
            // Log the saved file path for debugging
            currentRecordingPath?.let { path ->
                val file = File(path)
                if (file.exists()) {
                    Logger.d("[ForegroundService] WAV file saved: $path (${file.length()} bytes)")
                } else {
                    Logger.e("[ForegroundService] WAV file not found after finalization: $path")
                }
            }
        } catch (e: Exception) {
            Logger.e("[ForegroundService] Error finalizing recording on kill: ${e.message}", e)
        }
    }
    
    // ==================== Recording Methods ====================
    
    /**
     * Start WAV recording with the specified settings.
     * 
     * Note: outputFormat and audioEncoder parameters are ignored for WAV recording
     * as WAV always uses PCM format. They are kept for API compatibility.
     */
    fun startRecording(
        filePath: String,
        audioSource: Int,
        outputFormat: Int,
        audioEncoder: Int,
        samplingRate: Int?,
        channels: Int?,
        bitrate: Int?,
        enableMetering: Boolean,
        subscriptionDuration: Long
    ): Boolean {
        try {
            // Stop any existing recording
            stopRecordingInternal()
            
            // Ensure file path ends with .wav
            val wavFilePath = if (filePath.endsWith(".wav", ignoreCase = true)) {
                filePath
            } else {
                // Replace extension with .wav
                val basePath = filePath.substringBeforeLast(".")
                "$basePath.wav"
            }
            
            currentRecordingPath = wavFilePath
            meteringEnabled = enableMetering
            
            // Create and start WavRecorder
            wavRecorder = WavRecorder()
            val success = wavRecorder!!.startRecording(
                path = wavFilePath,
                audioSource = audioSource,
                sampleRateHz = samplingRate ?: 44100,
                channels = channels ?: 1,
                bitsPerSample = 16
            )
            
            if (!success) {
                Logger.e("[ForegroundService] Failed to start WAV recording")
                cleanupRecorder()
                return false
            }
            
            // Acquire wake lock while recording
            acquireWakeLock()
            
            // Start timer for recording updates
            startRecordTimer(subscriptionDuration)
            
            // Update notification
            updateNotification("Recording in progress...")
            
            Logger.d("[ForegroundService] WAV recording started: $wavFilePath")
            return true
        } catch (e: Exception) {
            Logger.e("[ForegroundService] Error starting recording: ${e.message}", e)
            cleanupRecorder()
            return false
        }
    }
    
    fun pauseRecording(): Boolean {
        val recorder = wavRecorder ?: return false
        
        return try {
            val success = recorder.pauseRecording()
            if (success) {
                stopRecordTimer()
                releaseWakeLock()
                updateNotification("Recording paused")
            }
            success
        } catch (e: Exception) {
            Logger.e("[ForegroundService] Error pausing recording: ${e.message}", e)
            false
        }
    }
    
    fun resumeRecording(): Boolean {
        val recorder = wavRecorder ?: return false
        
        return try {
            val success = recorder.resumeRecording()
            if (success) {
                acquireWakeLock()
                startRecordTimer(subscriptionDurationMs)
                updateNotification("Recording in progress...")
            }
            success
        } catch (e: Exception) {
            Logger.e("[ForegroundService] Error resuming recording: ${e.message}", e)
            false
        }
    }
    
    fun stopRecording(): String? {
        val path = currentRecordingPath
        stopRecordingInternal()
        return path
    }
    
    private fun stopRecordingInternal() {
        try {
            stopRecordTimer()
            
            wavRecorder?.stopRecording()
            wavRecorder = null
            
            // Reset metering
            meteringEnabled = false
            lastMeteringUpdateTime = 0L
            lastMeteringValue = SILENCE_THRESHOLD_DB
            
            // Release wake lock when recording stops
            releaseWakeLock()
        } catch (e: Exception) {
            Logger.e("[ForegroundService] Error in stopRecordingInternal: ${e.message}", e)
        }
    }
    
    private fun cleanupRecorder() {
        try {
            wavRecorder?.stopRecording()
        } catch (e: Exception) {
            // Ignore
        }
        wavRecorder = null
        currentRecordingPath = null
    }
    
    fun getRecordingPath(): String? = currentRecordingPath
    
    fun isCurrentlyRecording(): Boolean = wavRecorder?.isCurrentlyRecording() == true
    
    fun isCurrentlyPaused(): Boolean = wavRecorder?.isCurrentlyPaused() == true
    
    /**
     * Get current recording time in milliseconds.
     * Works for both recording and paused states.
     */
    fun getCurrentRecordingTime(): Double {
        return wavRecorder?.getCurrentDuration()?.toDouble() ?: 0.0
    }
    
    // ==================== Timer ====================
    
    private var subscriptionDurationMs: Long = 60L
    
    private fun startRecordTimer(durationMs: Long) {
        subscriptionDurationMs = durationMs
        recordTimer?.cancel()
        recordTimer = Timer()
        recordTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                val recorder = wavRecorder
                if (recorder == null || !recorder.isCurrentlyRecording()) {
                    return
                }
                
                val currentTime = recorder.getCurrentDuration()
                val meteringValue = if (meteringEnabled) {
                    val now = System.currentTimeMillis()
                    if (now - lastMeteringUpdateTime >= METERING_UPDATE_INTERVAL_MS) {
                        lastMeteringValue = recorder.getMeteringDb()
                        lastMeteringUpdateTime = now
                    }
                    lastMeteringValue
                } else {
                    METERING_DISABLED_VALUE
                }
                
                handler.post {
                    onRecordingUpdate?.invoke(
                        recorder.isCurrentlyRecording(),
                        currentTime.toDouble(),
                        meteringValue
                    )
                }
            }
        }, 0, durationMs)
    }
    
    private fun stopRecordTimer() {
        recordTimer?.cancel()
        recordTimer = null
    }
    
    // ==================== Notification ====================
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Audio recording in progress"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(contentText: String = "Tap to return to app"): Notification {
        val packageName = packageName
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent().apply { 
                // Fallback: create a basic intent if no launch activity found
                setPackage(packageName)
            }
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            pendingIntentFlags
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Recording audio")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
    
    private fun updateNotification(text: String) {
        val notification = createNotification(text)
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    // ==================== WakeLock ====================
    
    private val wakeLockHandler = Handler(Looper.getMainLooper())
    private var wakeLockRenewalRunnable: Runnable? = null
    
    private fun acquireWakeLock() {
        try {
            if (wakeLock?.isHeld == true) return // Already held
            
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                WAKE_LOCK_TAG
            ).apply {
                acquire(WAKE_LOCK_TIMEOUT_MS)
            }
            
            // Schedule periodic renewal while recording is active
            scheduleWakeLockRenewal()
        } catch (e: Exception) {
            Logger.e("[ForegroundService] Error acquiring wake lock: ${e.message}", e)
        }
    }
    
    private fun scheduleWakeLockRenewal() {
        wakeLockRenewalRunnable?.let { wakeLockHandler.removeCallbacks(it) }
        
        val runnable = Runnable {
            try {
                val recorder = wavRecorder
                if (recorder != null && recorder.isCurrentlyRecording()) {
                    // Renew the wake lock for another period
                    wakeLock?.let {
                        if (it.isHeld) {
                            it.release()
                        }
                    }
                    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                    wakeLock = powerManager.newWakeLock(
                        PowerManager.PARTIAL_WAKE_LOCK,
                        WAKE_LOCK_TAG
                    ).apply {
                        acquire(WAKE_LOCK_TIMEOUT_MS)
                    }
                    Logger.d("[ForegroundService] Wake lock renewed")
                    scheduleWakeLockRenewal()
                }
            } catch (e: Exception) {
                Logger.e("[ForegroundService] Error renewing wake lock: ${e.message}", e)
            }
        }
        wakeLockRenewalRunnable = runnable
        // Renew 1 minute before expiry
        wakeLockHandler.postDelayed(runnable, WAKE_LOCK_TIMEOUT_MS - 60_000L)
    }
    
    private fun releaseWakeLock() {
        try {
            wakeLockRenewalRunnable?.let { wakeLockHandler.removeCallbacks(it) }
            wakeLockRenewalRunnable = null
            
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                }
            }
            wakeLock = null
        } catch (e: Exception) {
            Logger.w("[ForegroundService] Error releasing wake lock: ${e.message}", e)
        }
    }
}
