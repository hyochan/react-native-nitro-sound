package com.margelo.nitro.audiorecorderplayer

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

class HybridAudioRecorderPlayer : HybridAudioRecorderPlayerSpec() {
    private var mediaRecorder: MediaRecorder? = null
    private var mediaPlayer: MediaPlayer? = null

    private var recordTimer: Timer? = null
    private var playTimer: Timer? = null

    private var recordBackListener: ((recordingMeta: RecordBackType) -> Unit)? = null
    private var playBackListener: ((playbackMeta: PlayBackType) -> Unit)? = null
    private var playbackEndListener: ((playbackEndMeta: PlaybackEndType) -> Unit)? = null

    private var subscriptionDuration: Long = 60L
    private var recordStartTime: Long = 0L
    private var pausedRecordTime: Long = 0L
    private var meteringEnabled: Boolean = false

    private val handler = Handler(Looper.getMainLooper())

    private val context: Context
        get() = NitroModules.applicationContext ?: throw IllegalStateException("Application context not available")

    // Recording methods
    override fun startRecorder(
        uri: String?,
        audioSets: AudioSet?,
        meteringEnabled: Boolean?
    ): Promise<String> {
        val promise = Promise<String>()

      // For audio metering
      this.meteringEnabled = meteringEnabled ?: false

        // Return immediately and process in background
        CoroutineScope(Dispatchers.IO).launch {
            try {
            // Create file path
            val filePath = uri ?: run {
                val dir = context.filesDir
                val fileName = "sound_${System.currentTimeMillis()}.mp4"
                File(dir, fileName).absolutePath
            }

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

                // Set audio sampling rate
                audioSets?.AudioSamplingRate?.let {
                    setAudioSamplingRate(it.toInt())
                }

                // Set audio channels
                audioSets?.AudioChannels?.let {
                    setAudioChannels(it.toInt())
                }

                // Set audio encoding bit rate
                audioSets?.AudioEncodingBitRate?.let {
                    setAudioEncodingBitRate(it.toInt())
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

                promise.resolve(filePath)
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

                handler.post {
                    stopRecordTimer()
                }

                promise.resolve("Recorder stopped")
            } catch (e: Exception) {
                mediaRecorder?.release()
                mediaRecorder = null
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
                    else -> {
                        // Handle local file
                        setDataSource(uri)
                    }
                }

                    // Prepare on IO thread
                    prepare()

                    // Start playback on main thread
                    handler.post {
                        start()
                        startPlayTimer()
                        promise.resolve(uri)
                    }

                    setOnErrorListener { _, what, extra ->
                        promise.reject(Exception("MediaPlayer error: what=$what, extra=$extra"))
                        true
                    }

                    setOnCompletionListener {
                        handler.post {
                            stopPlayTimer()

                            // Send final playback update
                            playBackListener?.invoke(
                                PlayBackType(
                                    isMuted = false,
                                    duration = duration.toDouble(),
                                    currentPosition = duration.toDouble()
                                )
                            )

                            // Send playback end event
                            playbackEndListener?.invoke(
                                PlaybackEndType(
                                    duration = duration.toDouble(),
                                    currentPosition = duration.toDouble()
                                )
                            )
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
                mediaPlayer?.let { player ->
                    player.playbackParams = player.playbackParams.apply {
                        speed = playbackSpeed.toFloat()
                    }
                    "Playback speed set to $playbackSpeed"
                } ?: throw Exception("No player instance")
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

    // Private methods

    // For audioMetering using mediaRecorder
    private fun getSimpleMetering(): Double {
      return try {
        val maxAmplitude = mediaRecorder?.maxAmplitude ?: 0
        if (maxAmplitude > 0) {
          // Convert amplitude to decibels
          // getMaxAmplitude() returns values from 0 to 32767
          val normalizedAmplitude = maxAmplitude.toDouble() / 32767.0
          val decibels = 20 * log10(normalizedAmplitude)
          maxOf(-160.0, minOf(0.0, decibels))
        } else {
          -160.0
        }
      } catch (e: Exception) {
        -160.0
      }
    }

    private fun startRecordTimer() {
        recordTimer?.cancel()
        recordTimer = Timer()
        recordTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                val currentTime = System.currentTimeMillis() - recordStartTime
                val meteringValue = if (meteringEnabled) {
                  getSimpleMetering()
                } else {
                  0.0
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
                    handler.post {
                        playBackListener?.invoke(
                            PlayBackType(
                                isMuted = false,
                                duration = player.duration.toDouble(),
                                currentPosition = player.currentPosition.toDouble()
                            )
                        )
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
