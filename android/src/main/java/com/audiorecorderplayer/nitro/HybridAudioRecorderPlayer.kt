package com.audiorecorderplayer.nitro

import android.media.AudioManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.WritableMap
import com.facebook.react.bridge.Arguments
import com.margelo.nitro.NitroModules
import com.margelo.nitro.com.audiorecorderplayer.*
import java.io.File
import java.util.Timer
import java.util.TimerTask
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCoroutine

class HybridAudioRecorderPlayer(private val context: ReactApplicationContext) : HybridAudioRecorderPlayerSpec() {
    companion object {
        private const val TAG = "AudioRecorderPlayer"
        private const val MILLISECOND = 1000
        private const val DEFAULT_UPDATE_INTERVAL = 25L // 25ms for smooth updates like KMP
    }

    private var mediaRecorder: MediaRecorder? = null
    private var mediaPlayer: MediaPlayer? = null
    private var recordTimer: Timer? = null
    private var playbackTimer: Timer? = null
    
    private var recordingCallback: ((RecordBackType) -> Unit)? = null
    private var playbackCallback: ((PlayBackType) -> Unit)? = null
    
    private var subscriptionDuration = DEFAULT_UPDATE_INTERVAL
    private var recordTime = 0L
    private var pausedRecordTime = 0L
    private var pausedPlayTime = 0L
    private var recordStartTime = 0L
    
    private var recordFilePath: String? = null
    private var isRecording = false
    private var isPaused = false
    private var isPlayerPaused = false
    private var meteringEnabled = false
    
    override val memorySize: Long
        get() = 64L
    
    // Recording Methods
    override suspend fun startRecorder(uri: String?, audioSets: AudioSet?, meteringEnabled: Boolean): String = suspendCoroutine { continuation ->
        try {
            val filePath = uri ?: run {
                val dir = context.cacheDir
                val fileName = "sound_${System.currentTimeMillis()}.mp4"
                File(dir, fileName).absolutePath
            }
            
            recordFilePath = filePath
            this.meteringEnabled = meteringEnabled
            
            mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(context)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }.apply {
                setAudioSource(audioSets?.AudioSourceAndroid ?: MediaRecorder.AudioSource.MIC)
                setOutputFormat(audioSets?.OutputFormatAndroid ?: MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(audioSets?.AudioEncoderAndroid ?: MediaRecorder.AudioEncoder.AAC)
                
                audioSets?.AudioSamplingRateAndroid?.let { setAudioSamplingRate(it.toInt()) }
                audioSets?.AudioEncodingBitRateAndroid?.let { setAudioEncodingBitRate(it.toInt()) }
                audioSets?.AudioChannelsAndroid?.let { setAudioChannels(it.toInt()) }
                
                setOutputFile(filePath)
                
                prepare()
                start()
            }
            
            isRecording = true
            isPaused = false
            pausedRecordTime = 0
            recordTime = System.currentTimeMillis()
            recordStartTime = System.currentTimeMillis()
            
            startRecordTimer()
            
            continuation.resume(filePath)
        } catch (e: Exception) {
            Log.e(TAG, "Error starting recorder", e)
            continuation.resumeWithException(e)
        }
    }
    
    override suspend fun pauseRecorder(): String = suspendCoroutine { continuation ->
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                mediaRecorder?.pause()
                pausedRecordTime = System.currentTimeMillis() - recordTime
                isPaused = true
                stopRecordTimer()
                continuation.resume("Recording paused")
            } else {
                continuation.resumeWithException(Exception("Pause recording is not supported on API level < 24"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error pausing recorder", e)
            continuation.resumeWithException(e)
        }
    }
    
    override suspend fun resumeRecorder(): String = suspendCoroutine { continuation ->
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                mediaRecorder?.resume()
                recordTime = System.currentTimeMillis() - pausedRecordTime
                isPaused = false
                startRecordTimer()
                continuation.resume("Recording resumed")
            } else {
                continuation.resumeWithException(Exception("Resume recording is not supported on API level < 24"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error resuming recorder", e)
            continuation.resumeWithException(e)
        }
    }
    
    override suspend fun stopRecorder(): String = suspendCoroutine { continuation ->
        try {
            // Calculate final recording duration before stopping
            val finalDuration = if (isPaused) {
                pausedRecordTime
            } else {
                System.currentTimeMillis() - recordTime + pausedRecordTime
            }
            Log.d(TAG, "Final recording duration: ${finalDuration}ms")
            
            mediaRecorder?.apply {
                stop()
                release()
            }
            mediaRecorder = null
            
            isRecording = false
            isPaused = false
            stopRecordTimer()
            
            val path = recordFilePath ?: ""
            recordFilePath = null
            
            continuation.resume(path)
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping recorder", e)
            continuation.resumeWithException(e)
        }
    }
    
    // Playback Methods
    override suspend fun startPlayer(uri: String?, httpHeaders: Record<String, String>?): String = suspendCoroutine { continuation ->
        try {
            val path = uri ?: recordFilePath ?: throw Exception("No file to play")
            Log.d(TAG, "Starting player with path: $path")
            
            mediaPlayer = MediaPlayer().apply {
                if (path.startsWith("http://") || path.startsWith("https://")) {
                    val headers = httpHeaders?.let { record ->
                        val map = mutableMapOf<String, String>()
                        for (i in 0 until record.size) {
                            val key = record.getKeyAt(i)
                            val value = record.getValueAt(i)
                            if (key != null && value != null) {
                                map[key] = value
                            }
                        }
                        map
                    }
                    setDataSource(context, Uri.parse(path), headers)
                } else {
                    // Check if file exists
                    val file = File(path)
                    if (!file.exists()) {
                        Log.e(TAG, "File does not exist: $path")
                        throw Exception("File does not exist: $path")
                    }
                    Log.d(TAG, "File exists, size: ${file.length()} bytes")
                    setDataSource(path)
                }
                
                setAudioStreamType(AudioManager.STREAM_MUSIC)
                prepareAsync()
                
                setOnPreparedListener { mp ->
                    mp.start()
                    isPlayerPaused = false
                    pausedPlayTime = 0
                    
                    // Log the actual duration of the media file
                    val actualDuration = mp.duration
                    Log.d(TAG, "Media file actual duration: ${actualDuration}ms")
                    
                    // Send initial playback state
                    playbackCallback?.invoke(
                        PlayBackType(
                            isMuted = false,
                            currentPosition = 0.0,
                            duration = actualDuration.toDouble(),
                            isFinished = false
                        )
                    )
                    
                    startPlaybackTimer()
                    
                    // Resume the coroutine after successful preparation
                    continuation.resume(path)
                }
                
                setOnCompletionListener {
                    stopPlaybackTimer()
                    val duration = it.duration
                    playbackCallback?.invoke(
                        PlayBackType(
                            isMuted = false,
                            currentPosition = duration.toDouble(),
                            duration = duration.toDouble(),
                            isFinished = true
                        )
                    )
                }
                
                setOnErrorListener { mp, what, extra ->
                    Log.e(TAG, "MediaPlayer error: what=$what, extra=$extra")
                    continuation.resumeWithException(Exception("MediaPlayer error: what=$what, extra=$extra"))
                    true
                }
            }
            
            // Don't resume here - wait for onPreparedListener
        } catch (e: Exception) {
            Log.e(TAG, "Error starting player", e)
            continuation.resumeWithException(e)
        }
    }
    
    override suspend fun pausePlayer(): String = suspendCoroutine { continuation ->
        try {
            mediaPlayer?.let {
                pausedPlayTime = it.currentPosition.toLong()
                it.pause()
                isPlayerPaused = true
                stopPlaybackTimer()
                continuation.resume("Playback paused")
            } ?: continuation.resumeWithException(Exception("No playback in progress"))
        } catch (e: Exception) {
            Log.e(TAG, "Error pausing player", e)
            continuation.resumeWithException(e)
        }
    }
    
    override suspend fun resumePlayer(): String = suspendCoroutine { continuation ->
        try {
            mediaPlayer?.let {
                it.start()
                isPlayerPaused = false
                startPlaybackTimer()
                continuation.resume("Playback resumed")
            } ?: continuation.resumeWithException(Exception("No playback session"))
        } catch (e: Exception) {
            Log.e(TAG, "Error resuming player", e)
            continuation.resumeWithException(e)
        }
    }
    
    override suspend fun stopPlayer(): String = suspendCoroutine { continuation ->
        try {
            mediaPlayer?.apply {
                stop()
                release()
            }
            mediaPlayer = null
            
            isPlayerPaused = false
            stopPlaybackTimer()
            
            continuation.resume("Playback stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping player", e)
            continuation.resumeWithException(e)
        }
    }
    
    override suspend fun seekToPlayer(time: Double): String = suspendCoroutine { continuation ->
        try {
            mediaPlayer?.let {
                it.seekTo(time.toInt())
                continuation.resume("Seeked to ${time}ms")
            } ?: continuation.resumeWithException(Exception("No playback session"))
        } catch (e: Exception) {
            Log.e(TAG, "Error seeking player", e)
            continuation.resumeWithException(e)
        }
    }
    
    override suspend fun setVolume(volume: Double): String = suspendCoroutine { continuation ->
        try {
            mediaPlayer?.let {
                val volumeFloat = volume.toFloat()
                it.setVolume(volumeFloat, volumeFloat)
                continuation.resume("Volume set to $volume")
            } ?: continuation.resumeWithException(Exception("No playback session"))
        } catch (e: Exception) {
            Log.e(TAG, "Error setting volume", e)
            continuation.resumeWithException(e)
        }
    }
    
    override suspend fun setPlaybackSpeed(playbackSpeed: Double): String = suspendCoroutine { continuation ->
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                mediaPlayer?.let {
                    it.playbackParams = it.playbackParams.setSpeed(playbackSpeed.toFloat())
                    continuation.resume("Playback speed set to $playbackSpeed")
                } ?: continuation.resumeWithException(Exception("No playback session"))
            } else {
                continuation.resumeWithException(Exception("Playback speed is not supported on API level < 23"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error setting playback speed", e)
            continuation.resumeWithException(e)
        }
    }
    
    override suspend fun setSubscriptionDuration(sec: Double): String = suspendCoroutine { continuation ->
        subscriptionDuration = (sec * MILLISECOND).toLong()
        continuation.resume("Subscription duration set to ${sec}s")
    }
    
    // Event Listeners
    override fun onRecordingProgress(callback: (RecordBackType) -> Unit): Func_void {
        recordingCallback = callback
        return Func_void {
            recordingCallback = null
        }
    }
    
    override fun onPlaybackProgress(callback: (PlayBackType) -> Unit): Func_void {
        playbackCallback = callback
        return Func_void {
            playbackCallback = null
        }
    }
    
    // Private Methods
    private fun startRecordTimer() {
        recordTimer?.cancel()
        recordTimer = Timer()
        recordTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                Handler(Looper.getMainLooper()).post {
                    val currentTime = if (isPaused) {
                        pausedRecordTime
                    } else {
                        System.currentTimeMillis() - recordTime + pausedRecordTime
                    }
                    
                    // Calculate metering value
                    val meteringValue = if (meteringEnabled && !isPaused) {
                        try {
                            val maxAmplitude = mediaRecorder?.maxAmplitude ?: 0
                            Log.d(TAG, "Max amplitude: $maxAmplitude")
                            if (maxAmplitude > 0) {
                                // Convert amplitude (0-32767) to normalized level (0-1)
                                // Using square root for better visual response
                                val normalized = kotlin.math.sqrt(maxAmplitude / 32767.0).toFloat()
                                Log.d(TAG, "Normalized metering: $normalized")
                                normalized
                            } else {
                                // Send a small random noise to show the meter is working (like KMP)
                                val noise = 0.05f + kotlin.random.Random.nextFloat() * 0.05f
                                Log.d(TAG, "No amplitude, using noise: $noise")
                                noise
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error getting max amplitude", e)
                            0.0f
                        }
                    } else {
                        0.0f
                    }
                    
                    recordingCallback?.invoke(
                        RecordBackType(
                            isRecording = isRecording && !isPaused,
                            currentPosition = currentTime.toDouble(),
                            currentMetering = meteringValue.toDouble()
                        )
                    )
                }
            }
        }, 0, subscriptionDuration)
    }
    
    private fun stopRecordTimer() {
        recordTimer?.cancel()
        recordTimer = null
    }
    
    private fun startPlaybackTimer() {
        playbackTimer?.cancel()
        playbackTimer = Timer()
        playbackTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                Handler(Looper.getMainLooper()).post {
                    mediaPlayer?.let { player ->
                        try {
                            val currentPosition = player.currentPosition
                            val duration = player.duration
                            
                            // Ensure we have valid values
                            if (duration > 0) {
                                playbackCallback?.invoke(
                                    PlayBackType(
                                        isMuted = false,
                                        currentPosition = currentPosition.toDouble(),
                                        duration = duration.toDouble(),
                                        isFinished = false
                                    )
                                )
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error in playback timer", e)
                        }
                    }
                }
            }
        }, 0, subscriptionDuration)
    }
    
    private fun stopPlaybackTimer() {
        playbackTimer?.cancel()
        playbackTimer = null
    }
}