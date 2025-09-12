package com.margelo.nitro.sound

import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.content.Context
import com.facebook.react.bridge.ReactApplicationContext
import com.margelo.nitro.NitroModules
import com.margelo.nitro.core.Promise
import java.io.File
import java.util.Timer
import java.util.TimerTask
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlin.math.log10

class HybridSound : HybridSoundSpec() {
    private var mediaRecorder: MediaRecorder? = null
    private var mediaPlayer: MediaPlayer? = null
    private var currentRecordingPath: String? = null

    private var recordTimer: Timer? = null
    private var playTimer: Timer? = null

    private var recordBackListener: ((recordingMeta: RecordBackType) -> Unit)? = null
    private var playBackListener: ((playbackMeta: PlayBackType) -> Unit)? = null
    private var playbackEndListener: ((playbackEndMeta: PlaybackEndType) -> Unit)? = null

    private var subscriptionDuration: Long = 60L
    private var recordStartTime: Long = 0L
    private var pausedRecordTime: Long = 0L
    private var meteringEnabled: Boolean = false
    
    // Metering-related properties
    private var lastMeteringUpdateTime = 0L
    private var lastMeteringValue = SILENCE_THRESHOLD_DB

    private val handler = Handler(Looper.getMainLooper())

    private val context: Context
        get() = NitroModules.applicationContext ?: throw IllegalStateException("Application context not available")

    // Named constants with documentation
    companion object {
      /**
       * Minimum amplitude value to prevent log10(0) which would return negative infinity.
       * This represents the noise floor for audio metering calculations.
       */
      private const val MIN_AMPLITUDE_EPSILON = 1e-10

      /**
       * Silence threshold in decibels. Values below this are considered silence.
       * -160 dB is effectively digital silence.
       */
      private const val SILENCE_THRESHOLD_DB = -160.0

      /**
       * Maximum amplitude value from MediaRecorder.getMaxAmplitude().
       * Used for normalizing amplitude values to 0.0-1.0 range.
       */
      private const val MAX_AMPLITUDE_VALUE = 32767.0

      /**
       * Minimum interval between metering calculations to optimize performance.
       * Limits metering updates to 10Hz maximum (every 100ms).
       */
      private const val METERING_UPDATE_INTERVAL_MS = 100L

      /**
       * Maximum decibel level representing full scale amplitude (0 dB).
       */
      private const val MAX_DECIBEL_LEVEL = 0.0

      /**
       * Default metering value when metering is disabled.
       */
      private const val METERING_DISABLED_VALUE = 0.0
    }

    // Recording methods
    override fun startRecorder(
        uri: String?,
        audioSets: AudioSet?,
        enableMetering: Boolean?
    ): Promise<String> {
        val promise = Promise<String>()

      // For audio metering
      this.meteringEnabled = enableMetering ?: false

        // Return immediately and process in background
        CoroutineScope(Dispatchers.IO).launch {
            try {
            // Create file path
            val filePath = uri ?: run {
                val dir = context.filesDir
                val fileName = "sound_${System.currentTimeMillis()}.mp4"
                File(dir, fileName).absolutePath
            }
            // Store the recording path
            currentRecordingPath = filePath

            // Initialize MediaRecorder
            mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(context)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }.apply {
                // Set audio source
                val audioSource = when (audioSets?.AudioSourceAndroid) {
                    AudioSourceAndroidType.DEFAULT -> MediaRecorder.AudioSource.DEFAULT
                    AudioSourceAndroidType.MIC -> MediaRecorder.AudioSource.MIC
                    AudioSourceAndroidType.VOICE_UPLINK -> MediaRecorder.AudioSource.VOICE_UPLINK
                    AudioSourceAndroidType.VOICE_DOWNLINK -> MediaRecorder.AudioSource.VOICE_DOWNLINK
                    AudioSourceAndroidType.VOICE_CALL -> MediaRecorder.AudioSource.VOICE_CALL
                    AudioSourceAndroidType.CAMCORDER -> MediaRecorder.AudioSource.CAMCORDER
                    AudioSourceAndroidType.VOICE_RECOGNITION -> MediaRecorder.AudioSource.VOICE_RECOGNITION
                    AudioSourceAndroidType.VOICE_COMMUNICATION -> MediaRecorder.AudioSource.VOICE_COMMUNICATION
                    AudioSourceAndroidType.REMOTE_SUBMIX -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                        MediaRecorder.AudioSource.REMOTE_SUBMIX
                    } else {
                        MediaRecorder.AudioSource.MIC
                    }
                    AudioSourceAndroidType.UNPROCESSED -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        MediaRecorder.AudioSource.UNPROCESSED
                    } else {
                        MediaRecorder.AudioSource.MIC
                    }
                    AudioSourceAndroidType.RADIO_TUNER -> MediaRecorder.AudioSource.MIC // Not available in standard API
                    AudioSourceAndroidType.HOTWORD -> MediaRecorder.AudioSource.MIC // Not available in standard API
                    null -> MediaRecorder.AudioSource.MIC
                }
                setAudioSource(audioSource)

                // Set output format
                val outputFormat = when (audioSets?.OutputFormatAndroid) {
                    OutputFormatAndroidType.DEFAULT -> MediaRecorder.OutputFormat.DEFAULT
                    OutputFormatAndroidType.THREE_GPP -> MediaRecorder.OutputFormat.THREE_GPP
                    OutputFormatAndroidType.MPEG_4 -> MediaRecorder.OutputFormat.MPEG_4
                    OutputFormatAndroidType.AMR_NB -> MediaRecorder.OutputFormat.AMR_NB
                    OutputFormatAndroidType.AMR_WB -> MediaRecorder.OutputFormat.AMR_WB
                    OutputFormatAndroidType.AAC_ADIF -> MediaRecorder.OutputFormat.MPEG_4 // AAC_ADIF not available
                    OutputFormatAndroidType.AAC_ADTS -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
                        MediaRecorder.OutputFormat.AAC_ADTS
                    } else {
                        MediaRecorder.OutputFormat.MPEG_4
                    }
                    OutputFormatAndroidType.OUTPUT_FORMAT_RTP_AVP -> MediaRecorder.OutputFormat.MPEG_4 // RTP_AVP not available
                    OutputFormatAndroidType.MPEG_2_TS -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB) {
                        MediaRecorder.OutputFormat.MPEG_2_TS
                    } else {
                        MediaRecorder.OutputFormat.MPEG_4
                    }
                    OutputFormatAndroidType.WEBM -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        MediaRecorder.OutputFormat.WEBM
                    } else {
                        MediaRecorder.OutputFormat.MPEG_4
                    }
                    null -> MediaRecorder.OutputFormat.MPEG_4
                }
                setOutputFormat(outputFormat)

                // Set audio encoder
                val audioEncoder = when (audioSets?.AudioEncoderAndroid) {
                    AudioEncoderAndroidType.DEFAULT -> MediaRecorder.AudioEncoder.DEFAULT
                    AudioEncoderAndroidType.AMR_NB -> MediaRecorder.AudioEncoder.AMR_NB
                    AudioEncoderAndroidType.AMR_WB -> MediaRecorder.AudioEncoder.AMR_WB
                    AudioEncoderAndroidType.AAC -> MediaRecorder.AudioEncoder.AAC
                    AudioEncoderAndroidType.HE_AAC -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
                        MediaRecorder.AudioEncoder.HE_AAC
                    } else {
                        MediaRecorder.AudioEncoder.AAC
                    }
                    AudioEncoderAndroidType.AAC_ELD -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
                        MediaRecorder.AudioEncoder.AAC_ELD
                    } else {
                        MediaRecorder.AudioEncoder.AAC
                    }
                    AudioEncoderAndroidType.VORBIS -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        MediaRecorder.AudioEncoder.VORBIS
                    } else {
                        MediaRecorder.AudioEncoder.AAC
                    }
                    null -> MediaRecorder.AudioEncoder.AAC
                }
                setAudioEncoder(audioEncoder)

                // Apply sane defaults based on AudioQuality when explicit values are missing
                // Default to HIGH if not provided
                val audioQuality = audioSets?.AudioQuality ?: AudioQualityType.MEDIUM

                // Audio Sampling Rate
                run {
                    val srExplicit = audioSets?.AudioSamplingRate
                    val srDefault = when (audioQuality) {
                        AudioQualityType.LOW -> 22050
                        AudioQualityType.MEDIUM -> 44100
                        AudioQualityType.HIGH -> 48000
                        else -> null
                    }
                    val srFinal = (srExplicit?.toInt()) ?: srDefault
                    srFinal?.let { setAudioSamplingRate(it) }
                }

                // Audio Channels
                run {
                    val chExplicit = audioSets?.AudioChannels
                    val chDefault = when (audioQuality) {
                        AudioQualityType.LOW -> 1
                        AudioQualityType.MEDIUM -> 1
                        AudioQualityType.HIGH -> 2
                        else -> null
                    }
                    val chFinal = (chExplicit?.toInt()) ?: chDefault
                    chFinal?.let { setAudioChannels(it) }
                }

                // Audio Encoding Bitrate
                run {
                    val brExplicit = audioSets?.AudioEncodingBitRate
                    val brDefault = when (audioQuality) {
                        AudioQualityType.LOW -> 64000
                        AudioQualityType.MEDIUM -> 128000
                        AudioQualityType.HIGH -> 192000
                        else -> null
                    }
                    val brFinal = (brExplicit?.toInt()) ?: brDefault
                    brFinal?.let { setAudioEncodingBitRate(it) }
                }

                // Set output file
                setOutputFile(filePath)

                // Prepare and start
                prepare()
                start()
            }

                recordStartTime = System.currentTimeMillis()
                pausedRecordTime = 0L

                // Start timer on main thread
                handler.post {
                    startRecordTimer()
                }

                val fileUri = Uri.fromFile(File(filePath)).toString()
                promise.resolve(fileUri)
            } catch (e: Exception) {
                promise.reject(e)
            }
        }

        return promise
    }

    override fun pauseRecorder(): Promise<String> {
        return Promise.parallel {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                mediaRecorder?.pause()
                pausedRecordTime = System.currentTimeMillis() - recordStartTime
                stopRecordTimer()
                "Recorder paused"
            } else {
                throw Exception("Pause is not supported on Android API < 24")
            }
        }
    }

    override fun resumeRecorder(): Promise<String> {
        return Promise.parallel {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                mediaRecorder?.resume()
                recordStartTime = System.currentTimeMillis() - pausedRecordTime
                startRecordTimer()
                "Recorder resumed"
            } else {
                throw Exception("Resume is not supported on Android API < 24")
            }
        }
    }

    override fun stopRecorder(): Promise<String> {
        val promise = Promise<String>()

        // Return immediately and process in background
        CoroutineScope(Dispatchers.IO).launch {
            try {
                mediaRecorder?.apply {
                    stop()
                    release()
                }
                mediaRecorder = null

                // Reset metering state
                meteringEnabled = false
                lastMeteringUpdateTime = 0L
                lastMeteringValue = SILENCE_THRESHOLD_DB

                handler.post {
                    stopRecordTimer()
                }

                val path = currentRecordingPath
                currentRecordingPath = null // State is cleared regardless of outcome
                
                path?.let { 
                    val fileUri = Uri.fromFile(File(it)).toString()
                    promise.resolve(fileUri)
                } ?: promise.reject(Exception("Recorder not started or path is unavailable."))
            } catch (e: Exception) {
                mediaRecorder?.release()
                mediaRecorder = null

                // Reset metering state even on error
                meteringEnabled = false
                lastMeteringUpdateTime = 0L
                lastMeteringValue = SILENCE_THRESHOLD_DB

                promise.reject(e)
            }
        }

        return promise
    }

    // Playback methods
    override fun startPlayer(
        uri: String?,
        httpHeaders: Map<String, String>?
    ): Promise<String> {
        val promise = Promise<String>()

        // Return immediately and process in background
        CoroutineScope(Dispatchers.IO).launch {
            try {
                if (uri == null) {
                    promise.reject(Exception("URI is required"))
                    return@launch
                }

                // Clean up any existing player first
                mediaPlayer?.let { existingPlayer ->
                    try {
                        if (existingPlayer.isPlaying) {
                            existingPlayer.stop()
                        }
                        existingPlayer.reset()
                        existingPlayer.release()
                    } catch (e: Exception) {
                        // Ignore cleanup errors
                    }
                }

                handler.post {
                    stopPlayTimer()
                }

            mediaPlayer = MediaPlayer().apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    setAudioAttributes(
                        android.media.AudioAttributes.Builder()
                            .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                            .setContentType(android.media.AudioAttributes.CONTENT_TYPE_MUSIC)
                            .build()
                    )
                } else {
                    @Suppress("DEPRECATION")
                    setAudioStreamType(AudioManager.STREAM_MUSIC)
                }

                // Track if promise has been resolved to avoid double resolution
                val isPromiseResolved = java.util.concurrent.atomic.AtomicBoolean(false)

                // Set up error listener BEFORE any operations that might fail
                setOnErrorListener { _, what, extra ->
                    handler.post {
                        stopPlayTimer()
                        if (isPromiseResolved.compareAndSet(false, true)) {
                            promise.reject(Exception("MediaPlayer error: what=$what, extra=$extra"))
                        }
                    }
                    // Log error for debugging but don't try to reject promise again
                    true
                }

                setOnCompletionListener { player ->
                    handler.post {
                        stopPlayTimer()

                        // Get duration safely
                        val safeDuration = try {
                            player.duration.toDouble()
                        } catch (e: IllegalStateException) {
                            0.0
                        }

                        // Send final playback update
                        playBackListener?.invoke(
                            PlayBackType(
                                isMuted = false,
                                duration = safeDuration,
                                currentPosition = safeDuration
                            )
                        )

                        // Send playback end event
                        playbackEndListener?.invoke(
                            PlaybackEndType(
                                duration = safeDuration,
                                currentPosition = safeDuration
                            )
                        )
                    }
                }

                when {
                    uri.startsWith("http") -> {
                        // Handle network audio
                        val headers = httpHeaders ?: emptyMap()
                        setDataSource(context, Uri.parse(uri), headers)
                    }
                    uri.startsWith("content://") -> {
                        // Handle content URI
                        setDataSource(context, Uri.parse(uri))
                    }
                    uri.startsWith("file://") -> {
                        // Handle file URI
                        setDataSource(context, Uri.parse(uri))
                    }
                    else -> {
                        // Handle local file paths
                        setDataSource(uri)
                    }
                }

                    // Prepare on IO thread
                    prepare()

                    // Start playback on main thread
                    handler.post {
                        try {
                            if (isPromiseResolved.compareAndSet(false, true)) {
                                start()
                                startPlayTimer()
                                promise.resolve(uri)
                            }
                        } catch (e: Exception) {
                            // If start() fails, make sure we don't leave promise unresolved
                            if (isPromiseResolved.compareAndSet(false, true)) {
                                promise.reject(Exception("Failed to start MediaPlayer: ${e.message}", e))
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                promise.reject(e)
            }
        }

        return promise
    }

    override fun stopPlayer(): Promise<String> {
        val promise = Promise<String>()

        // Return immediately and process in background
        CoroutineScope(Dispatchers.IO).launch {
            try {
                mediaPlayer?.let { player ->
                    // Check if player is in a valid state before stopping
                    if (player.isPlaying) {
                        player.stop()
                    }
                    player.reset()
                    player.release()
                }
                mediaPlayer = null

                handler.post {
                    stopPlayTimer()
                }

                promise.resolve("Player stopped")
            } catch (e: Exception) {
                // Ensure cleanup even if error occurs
                try {
                    mediaPlayer?.reset()
                    mediaPlayer?.release()
                } catch (releaseError: Exception) {
                    // Ignore errors during cleanup
                }
                mediaPlayer = null

                handler.post {
                    stopPlayTimer()
                }

                promise.reject(e)
            }
        }

        return promise
    }

    override fun pausePlayer(): Promise<String> {
        return Promise.parallel {
            mediaPlayer?.pause()
            stopPlayTimer()
            "Player paused"
        }
    }

    override fun resumePlayer(): Promise<String> {
        return Promise.parallel {
            mediaPlayer?.start()
            startPlayTimer()
            "Player resumed"
        }
    }

    override fun seekToPlayer(time: Double): Promise<String> {
        return Promise.parallel {
            mediaPlayer?.seekTo(time.toInt())
            "Seeked to ${time}ms"
        }
    }

    override fun setVolume(volume: Double): Promise<String> {
        return Promise.parallel {
            val volumeFloat = volume.toFloat()
            mediaPlayer?.setVolume(volumeFloat, volumeFloat)
            "Volume set to $volume"
        }
    }

    override fun setPlaybackSpeed(playbackSpeed: Double): Promise<String> {
        return Promise.parallel {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val player = mediaPlayer ?: throw Exception("No player instance")
                try {
                    val params = try {
                        player.playbackParams
                    } catch (_: Exception) {
                        android.media.PlaybackParams()
                    }
                    params.speed = playbackSpeed.toFloat()
                    player.playbackParams = params
                    "Playback speed set to $playbackSpeed"
                } catch (e: Exception) {
                    throw e
                }
            } else {
                throw Exception("Playback speed is not supported on Android API < 23")
            }
        }
    }

    // Subscription
    override fun setSubscriptionDuration(sec: Double) {
        subscriptionDuration = (sec * 1000).toLong()
    }

    // Listeners
    override fun addRecordBackListener(callback: (recordingMeta: RecordBackType) -> Unit) {
        recordBackListener = callback
    }

    override fun removeRecordBackListener() {
        recordBackListener = null
    }

    override fun addPlayBackListener(callback: (playbackMeta: PlayBackType) -> Unit) {
        playBackListener = callback
    }

    override fun removePlayBackListener() {
        playBackListener = null
    }

    override fun addPlaybackEndListener(callback: (playbackEndMeta: PlaybackEndType) -> Unit) {
        handler.post {
            playbackEndListener = callback
        }
    }

    override fun removePlaybackEndListener() {
        handler.post {
            playbackEndListener = null
        }
    }

    // Utility methods
    override fun mmss(secs: Double): String {
        val totalSeconds = secs.toInt()
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        return String.format("%02d:%02d", minutes, seconds)
    }

    override fun mmssss(milisecs: Double): String {
        val totalSeconds = (milisecs / 1000).toInt()
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        val milliseconds = ((milisecs % 1000) / 10).toInt()
        return String.format("%02d:%02d:%02d", minutes, seconds, milliseconds)
    }

    // Removed redundant meteringUpdateInterval property; using METERING_UPDATE_INTERVAL_MS directly

    // Private methods
    // For audioMetering using mediaRecorder
    private fun getSimpleMetering(): Double {
      return try {
        val maxAmplitude = mediaRecorder?.maxAmplitude ?: 0
        if (maxAmplitude > 0) {
          // Convert amplitude to decibels
          // getMaxAmplitude() returns values from 0 to 32767
          val normalizedAmplitude = maxAmplitude.toDouble() / MAX_AMPLITUDE_VALUE

          // Use epsilon to prevent log10(0) which would return negative infinity
          val safeAmplitude = maxOf(normalizedAmplitude, MIN_AMPLITUDE_EPSILON)
          val decibels = 20 * log10(safeAmplitude)

          // Clamp to reasonable dB range (silence threshold to 0 dB)
          maxOf(SILENCE_THRESHOLD_DB, minOf(MAX_DECIBEL_LEVEL, decibels))
        } else {
          SILENCE_THRESHOLD_DB
        }
      } catch (e: IllegalStateException) {
        // MediaRecorder not in recording state
        SILENCE_THRESHOLD_DB
      } catch (e: Exception) {
        // Handle any other exceptions
        SILENCE_THRESHOLD_DB
      }
    }

    private fun startRecordTimer() {
        recordTimer?.cancel()
        recordTimer = Timer()
        recordTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                val currentTime = System.currentTimeMillis() - recordStartTime
                val meteringValue = if (meteringEnabled) {
                  val now = System.currentTimeMillis()
                  if (now - lastMeteringUpdateTime >= METERING_UPDATE_INTERVAL_MS) {
                    lastMeteringValue = getSimpleMetering()
                    lastMeteringUpdateTime = now
                  }
                  lastMeteringValue
                } else {
                  METERING_DISABLED_VALUE
                }

                handler.post {
                    recordBackListener?.invoke(
                        RecordBackType(
                            isRecording = true,
                            currentPosition = currentTime.toDouble(),
                            currentMetering = meteringValue, // Added metering value using mediaRecorder
                            recordSecs = currentTime.toDouble()
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

    private fun startPlayTimer() {
        playTimer?.cancel()
        playTimer = Timer()
        playTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                mediaPlayer?.let { player ->
                    try {
                        // Check if player is in valid state for getting duration/position
                        val safeDuration = try {
                            player.duration.toDouble()
                        } catch (e: IllegalStateException) {
                            -1.0 // Invalid state, skip this update
                        }
                        
                        val safeCurrentPosition = try {
                            player.currentPosition.toDouble()
                        } catch (e: IllegalStateException) {
                            -1.0 // Invalid state, skip this update
                        }
                        
                        // Only invoke callback if we have valid data
                        if (safeDuration >= 0 && safeCurrentPosition >= 0) {
                            handler.post {
                                playBackListener?.invoke(
                                    PlayBackType(
                                        isMuted = false,
                                        duration = safeDuration,
                                        currentPosition = safeCurrentPosition
                                    )
                                )
                            }
                        }
                    } catch (e: Exception) {
                        // MediaPlayer might be in invalid state, stop timer
                        handler.post {
                            stopPlayTimer()
                        }
                    }
                }
            }
        }, 0, subscriptionDuration)
    }

    private fun stopPlayTimer() {
        playTimer?.cancel()
        playTimer = null
    }
}
