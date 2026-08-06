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

    // Returned by repeated stopRecorder() calls so every call yields the same
    // file URI instead of a sentinel string a caller could mistake for a path.
    private var lastRecordingUri: String? = null

    private var recordTimer: Timer? = null
    private var playTimer: Timer? = null
    private val mediaPlayerLock = Any()
    private var playerGeneration = 0L

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
        meteringEnabled: Boolean?
    ): Promise<String> {
        val promise = Promise<String>()

      // For audio metering
      this.meteringEnabled = meteringEnabled ?: false

                // Sanitize audioSets to ignore iOS-specific fields on Android to prevent crashes
        val sanitizedAudioSets = audioSets?.copy(
            AVEncoderAudioQualityKeyIOS = null,
            AVModeIOS = null,
            AVEncodingOptionIOS = null,
            AVFormatIDKeyIOS = null,
            AVNumberOfChannelsKeyIOS = null,
            AVLinearPCMBitDepthKeyIOS = null,
            AVLinearPCMIsBigEndianKeyIOS = null,
            AVLinearPCMIsFloatKeyIOS = null,
            AVLinearPCMIsNonInterleavedIOS = null,
            AVSampleRateKeyIOS = null
        )

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
                val audioSource = when (sanitizedAudioSets?.AudioSourceAndroid) {
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
                val outputFormat = when (sanitizedAudioSets?.OutputFormatAndroid) {
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
                val audioEncoder = when (sanitizedAudioSets?.AudioEncoderAndroid) {
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
                val audioQuality = sanitizedAudioSets?.AudioQuality ?: AudioQualityType.HIGH

                // Define quality presets to avoid repetition
                data class QualitySettings(val samplingRate: Int, val channels: Int, val bitrate: Int)
                val presets = mapOf(
                    AudioQualityType.LOW to QualitySettings(22050, 1, 64000),
                    AudioQualityType.MEDIUM to QualitySettings(44100, 1, 128000),
                    AudioQualityType.HIGH to QualitySettings(48000, 2, 192000)
                )
                val defaults = presets[audioQuality]

                // Apply settings with explicit overrides taking precedence
                val samplingRate = sanitizedAudioSets?.AudioSamplingRate?.toInt() ?: defaults?.samplingRate
                samplingRate?.let { setAudioSamplingRate(it) }

                val channels = sanitizedAudioSets?.AudioChannels?.toInt() ?: defaults?.channels
                channels?.let { setAudioChannels(it) }

                val bitrate = sanitizedAudioSets?.AudioEncodingBitRate?.toInt() ?: defaults?.bitrate
                bitrate?.let { setAudioEncodingBitRate(it) }

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
                val recorder = mediaRecorder
                if (recorder == null) {
                    // stopRecorder is idempotent: a second call after the recorder
                    // was already stopped resolves with the same URI as the first
                    // one, so a double-tapped stop button cannot hand the caller a
                    // sentinel string where it expects a file path (#789, #693).
                    handler.post {
                        stopRecordTimer()
                    }
                    promise.resolve(lastRecordingUri ?: "recorder already stopped")
                    return@launch
                }

                recorder.apply {
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
                    lastRecordingUri = fileUri
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
        val isPromiseSettled = java.util.concurrent.atomic.AtomicBoolean(false)
        stopPlayTimer()

        // Return immediately and process in background
        CoroutineScope(Dispatchers.IO).launch {
            if (uri == null) {
                if (isPromiseSettled.compareAndSet(false, true)) {
                    promise.reject(Exception("URI is required"))
                }
                return@launch
            }

            val player = MediaPlayer()
            var generation = 0L

            try {
                synchronized(mediaPlayerLock) {
                    generation = ++playerGeneration
                    mediaPlayer?.let(::releaseMediaPlayer)
                    mediaPlayer = player

                    player.apply {
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

                        // Set up the listener before data-source and prepare operations.
                        setOnErrorListener { failedPlayer, what, extra ->
                            handler.post {
                                val isActive = synchronized(mediaPlayerLock) {
                                    if (
                                        playerGeneration == generation &&
                                        mediaPlayer === failedPlayer
                                    ) {
                                        mediaPlayer = null
                                        playerGeneration++
                                        releaseMediaPlayer(failedPlayer)
                                        true
                                    } else {
                                        false
                                    }
                                }
                                if (isActive) {
                                    stopPlayTimer()
                                    if (isPromiseSettled.compareAndSet(false, true)) {
                                        promise.reject(
                                            Exception("MediaPlayer error: what=$what, extra=$extra")
                                        )
                                    }
                                }
                            }
                            true
                        }

                        setOnCompletionListener { completedPlayer ->
                            val safeDuration = synchronized(mediaPlayerLock) {
                                if (
                                    playerGeneration != generation ||
                                    mediaPlayer !== completedPlayer
                                ) {
                                    return@setOnCompletionListener
                                }
                                try {
                                    completedPlayer.duration.toDouble()
                                } catch (_: IllegalStateException) {
                                    0.0
                                }
                            }

                            handler.post {
                                val isActive = synchronized(mediaPlayerLock) {
                                    playerGeneration == generation &&
                                        mediaPlayer === completedPlayer
                                }
                                if (!isActive) return@post

                                stopPlayTimer()
                                playBackListener?.invoke(
                                    PlayBackType(
                                        isMuted = false,
                                        duration = safeDuration,
                                        currentPosition = safeDuration
                                    )
                                )

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
                                val headers = httpHeaders ?: emptyMap()
                                setDataSource(context, Uri.parse(uri), headers)
                            }
                            uri.startsWith("content://") || uri.startsWith("android.resource://") -> {
                                setDataSource(context, Uri.parse(uri))
                            }
                            uri.startsWith("file://") -> {
                                setDataSource(context, Uri.parse(uri))
                            }
                            else -> {
                                setDataSource(uri)
                            }
                        }

                        prepare()
                    }
                }

                handler.post {
                    try {
                        synchronized(mediaPlayerLock) {
                            if (playerGeneration != generation || mediaPlayer !== player) {
                                throw IllegalStateException("Player start was superseded")
                            }
                            player.start()
                            if (isPromiseSettled.compareAndSet(false, true)) {
                                startPlayTimer()
                                promise.resolve(uri)
                            }
                        }
                    } catch (e: Exception) {
                        if (isPromiseSettled.compareAndSet(false, true)) {
                            promise.reject(Exception("Failed to start MediaPlayer: ${e.message}", e))
                        }
                    }
                }
            } catch (e: Exception) {
                synchronized(mediaPlayerLock) {
                    if (playerGeneration == generation && mediaPlayer === player) {
                        mediaPlayer = null
                        playerGeneration++
                    }
                    releaseMediaPlayer(player)
                }
                if (isPromiseSettled.compareAndSet(false, true)) {
                    promise.reject(e)
                }
            }
        }

        return promise
    }

    override fun stopPlayer(): Promise<String> {
        val promise = Promise<String>()
        stopPlayTimer()

        // Return immediately and process in background
        CoroutineScope(Dispatchers.IO).launch {
            try {
                synchronized(mediaPlayerLock) {
                    playerGeneration++
                    val player = mediaPlayer
                    mediaPlayer = null
                    player?.let(::releaseMediaPlayer)
                }

                promise.resolve("Player stopped")
            } catch (e: Exception) {
                // Ensure cleanup even if error occurs
                try {
                    synchronized(mediaPlayerLock) {
                        playerGeneration++
                        mediaPlayer?.let(::releaseMediaPlayer)
                        mediaPlayer = null
                    }
                } catch (_: Exception) {
                    // Ignore errors during cleanup
                }

                promise.reject(e)
            }
        }

        return promise
    }

    override fun pausePlayer(): Promise<String> {
        return Promise.parallel {
            synchronized(mediaPlayerLock) {
                val player = mediaPlayer ?: throw Exception("No player instance")
                player.pause()
                stopPlayTimer()
            }
            "Player paused"
        }
    }

    override fun resumePlayer(): Promise<String> {
        return Promise.parallel {
            synchronized(mediaPlayerLock) {
                // Rejecting instead of silently succeeding matches iOS; a released
                // player otherwise makes resume look like a no-op with no error (#626).
                val player = mediaPlayer ?: throw Exception("No player instance")
                player.start()
                startPlayTimer()
            }
            "Player resumed"
        }
    }

    override fun seekToPlayer(time: Double): Promise<String> {
        return Promise.parallel {
            synchronized(mediaPlayerLock) {
                val player = mediaPlayer ?: throw Exception("No player instance")
                player.seekTo(time.toInt())
            }
            "Seeked to ${time}ms"
        }
    }

    override fun setVolume(volume: Double): Promise<String> {
        return Promise.parallel {
            val volumeFloat = volume.toFloat()
            synchronized(mediaPlayerLock) {
                val player = mediaPlayer ?: throw Exception("No player instance")
                player.setVolume(volumeFloat, volumeFloat)
            }
            "Volume set to $volume"
        }
    }

    override fun setPlaybackSpeed(playbackSpeed: Double): Promise<String> {
        return Promise.parallel {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                synchronized(mediaPlayerLock) {
                    val player = mediaPlayer ?: throw Exception("No player instance")
                    val params = try {
                        player.playbackParams
                    } catch (_: Exception) {
                        android.media.PlaybackParams()
                    }
                    params.speed = playbackSpeed.toFloat()
                    player.playbackParams = params
                    "Playback speed set to $playbackSpeed"
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

    private fun releaseMediaPlayer(player: MediaPlayer) {
        try {
            player.setOnCompletionListener(null)
            player.setOnErrorListener(null)
        } catch (_: Exception) {
            // The player may already be released.
        }
        try {
            if (player.isPlaying) player.stop()
        } catch (_: Exception) {
            // Ignore invalid-state cleanup failures.
        }
        try {
            player.reset()
        } catch (_: Exception) {
            // Ignore invalid-state cleanup failures.
        }
        try {
            player.release()
        } catch (_: Exception) {
            // Ignore duplicate-release failures.
        }
    }

    private fun startPlayTimer() {
        playTimer?.cancel()
        playTimer = Timer()
        playTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                try {
                    val playbackSnapshot = synchronized(mediaPlayerLock) {
                        val player = mediaPlayer ?: return@synchronized null
                        val safeDuration = try {
                            player.duration.toDouble()
                        } catch (_: IllegalStateException) {
                            -1.0
                        }
                        val safeCurrentPosition = try {
                            player.currentPosition.toDouble()
                        } catch (_: IllegalStateException) {
                            -1.0
                        }

                        if (safeDuration >= 0 && safeCurrentPosition >= 0) {
                            Triple(
                                playerGeneration,
                                player,
                                PlayBackType(
                                    isMuted = false,
                                    duration = safeDuration,
                                    currentPosition = safeCurrentPosition
                                )
                            )
                        } else {
                            null
                        }
                    }

                    playbackSnapshot?.let { (generation, player, update) ->
                        handler.post {
                            val isActive = synchronized(mediaPlayerLock) {
                                playerGeneration == generation && mediaPlayer === player
                            }
                            if (isActive) {
                                playBackListener?.invoke(update)
                            }
                        }
                    }
                } catch (_: Exception) {
                    // MediaPlayer might be in an invalid state, stop timer
                    handler.post {
                        stopPlayTimer()
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
