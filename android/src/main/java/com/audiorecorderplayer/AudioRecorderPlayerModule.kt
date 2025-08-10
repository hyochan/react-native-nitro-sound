package com.audiorecorderplayer

import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.facebook.react.bridge.*
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.modules.core.DeviceEventManagerModule
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.File
import java.util.Timer
import java.util.TimerTask

@ReactModule(name = AudioRecorderPlayerModule.NAME)
class AudioRecorderPlayerModule(private val reactContext: ReactApplicationContext) :
  NativeAudioRecorderPlayerSpec(reactContext) {

  private var mediaRecorder: MediaRecorder? = null
  private var mediaPlayer: MediaPlayer? = null
  
  private var recordTimer: Timer? = null
  private var playTimer: Timer? = null
  
  private var hasRecordBackListener = false
  private var hasPlayBackListener = false
  
  private var subscriptionDuration: Long = 60L
  private var recordStartTime: Long = 0L
  private var pausedRecordTime: Long = 0L
  private var recordingFilePath: String? = null
  
  private val handler = Handler(Looper.getMainLooper())

  override fun getName(): String {
    return NAME
  }

  // Recording methods
  override fun startRecorder(
    uri: String?,
    audioSets: ReadableMap?,
    meteringEnabled: Boolean?,
    promise: Promise
  ) {
    CoroutineScope(Dispatchers.IO).launch {
      try {
        // Create file path
        val filePath = uri ?: run {
          val dir = reactContext.filesDir
          val fileName = "sound_${System.currentTimeMillis()}.mp4"
          File(dir, fileName).absolutePath
        }
        
        // Initialize MediaRecorder
        mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
          MediaRecorder(reactContext)
        } else {
          @Suppress("DEPRECATION")
          MediaRecorder()
        }.apply {
          // Set audio source
          val audioSource = audioSets?.getInt("AudioSourceAndroid")?.let {
            when (it) {
              0 -> MediaRecorder.AudioSource.DEFAULT
              1 -> MediaRecorder.AudioSource.MIC
              2 -> MediaRecorder.AudioSource.VOICE_UPLINK
              3 -> MediaRecorder.AudioSource.VOICE_DOWNLINK
              4 -> MediaRecorder.AudioSource.VOICE_CALL
              5 -> MediaRecorder.AudioSource.CAMCORDER
              6 -> MediaRecorder.AudioSource.VOICE_RECOGNITION
              7 -> MediaRecorder.AudioSource.VOICE_COMMUNICATION
              8 -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                MediaRecorder.AudioSource.REMOTE_SUBMIX
              } else {
                MediaRecorder.AudioSource.MIC
              }
              9 -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                MediaRecorder.AudioSource.UNPROCESSED
              } else {
                MediaRecorder.AudioSource.MIC
              }
              else -> MediaRecorder.AudioSource.MIC
            }
          } ?: MediaRecorder.AudioSource.MIC
          setAudioSource(audioSource)
          
          // Set output format
          val outputFormat = audioSets?.getInt("OutputFormatAndroid")?.let {
            when (it) {
              0 -> MediaRecorder.OutputFormat.DEFAULT
              1 -> MediaRecorder.OutputFormat.THREE_GPP
              2 -> MediaRecorder.OutputFormat.MPEG_4
              3 -> MediaRecorder.OutputFormat.AMR_NB
              4 -> MediaRecorder.OutputFormat.AMR_WB
              5 -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.FROYO) {
                MediaRecorder.OutputFormat.AAC_ADTS
              } else {
                MediaRecorder.OutputFormat.DEFAULT
              }
              6 -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                MediaRecorder.OutputFormat.WEBM
              } else {
                MediaRecorder.OutputFormat.DEFAULT
              }
              7 -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                MediaRecorder.OutputFormat.OGG
              } else {
                MediaRecorder.OutputFormat.DEFAULT
              }
              else -> MediaRecorder.OutputFormat.DEFAULT
            }
          } ?: MediaRecorder.OutputFormat.MPEG_4
          setOutputFormat(outputFormat)
          
          // Set audio encoder
          val audioEncoder = audioSets?.getInt("AudioEncoderAndroid")?.let {
            when (it) {
              0 -> MediaRecorder.AudioEncoder.DEFAULT
              1 -> MediaRecorder.AudioEncoder.AMR_NB
              2 -> MediaRecorder.AudioEncoder.AMR_WB
              3 -> MediaRecorder.AudioEncoder.AAC
              4 -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
                MediaRecorder.AudioEncoder.HE_AAC
              } else {
                MediaRecorder.AudioEncoder.AAC
              }
              5 -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
                MediaRecorder.AudioEncoder.AAC_ELD
              } else {
                MediaRecorder.AudioEncoder.AAC
              }
              6 -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                MediaRecorder.AudioEncoder.VORBIS
              } else {
                MediaRecorder.AudioEncoder.DEFAULT
              }
              7 -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaRecorder.AudioEncoder.OPUS
              } else {
                MediaRecorder.AudioEncoder.DEFAULT
              }
              else -> MediaRecorder.AudioEncoder.DEFAULT
            }
          } ?: MediaRecorder.AudioEncoder.AAC
          setAudioEncoder(audioEncoder)
          
          // Set additional audio settings
          audioSets?.let { sets ->
            if (sets.hasKey("AudioSampleRateAndroid")) {
              setAudioSamplingRate(sets.getInt("AudioSampleRateAndroid"))
            }
            if (sets.hasKey("AudioChannelsAndroid")) {
              setAudioChannels(sets.getInt("AudioChannelsAndroid"))
            }
            if (sets.hasKey("AudioEncodingBitRateAndroid")) {
              setAudioEncodingBitRate(sets.getInt("AudioEncodingBitRateAndroid"))
            }
          }
          
          setOutputFile(filePath)
          prepare()
          start()
        }
        
        recordStartTime = System.currentTimeMillis()
        pausedRecordTime = 0L
        recordingFilePath = filePath // Save the file path
        
        startRecordTimer()
        
        handler.post {
          promise.resolve(filePath)
        }
      } catch (e: Exception) {
        handler.post {
          promise.reject("recording_error", "Failed to start recording: ${e.message}", e)
        }
      }
    }
  }

  override fun pauseRecorder(promise: Promise) {
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        mediaRecorder?.pause()
        pausedRecordTime = System.currentTimeMillis() - recordStartTime
        stopRecordTimer()
        promise.resolve("Recording paused")
      } else {
        promise.reject("not_supported", "Pause recording is not supported on this Android version", null)
      }
    } catch (e: Exception) {
      promise.reject("pause_error", "Failed to pause recording: ${e.message}", e)
    }
  }

  override fun resumeRecorder(promise: Promise) {
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        mediaRecorder?.resume()
        recordStartTime = System.currentTimeMillis() - pausedRecordTime
        startRecordTimer()
        promise.resolve("Recording resumed")
      } else {
        promise.reject("not_supported", "Resume recording is not supported on this Android version", null)
      }
    } catch (e: Exception) {
      promise.reject("resume_error", "Failed to resume recording: ${e.message}", e)
    }
  }

  override fun stopRecorder(promise: Promise) {
    try {
      val filePath = recordingFilePath ?: ""
      
      mediaRecorder?.apply {
        stop()
        release()
      }
      mediaRecorder = null
      stopRecordTimer()
      
      // Get the actual file duration after recording stops
      var actualDuration = 0.0
      if (filePath.isNotEmpty()) {
        val tempPlayer = MediaPlayer()
        try {
          tempPlayer.setDataSource(filePath)
          tempPlayer.prepare()
          actualDuration = tempPlayer.duration.toDouble() // duration in milliseconds
          
          // Debug logging
          android.util.Log.d("AudioRecorderPlayer", "=== STOP RECORDER ===")
          android.util.Log.d("AudioRecorderPlayer", "File path: $filePath")
          android.util.Log.d("AudioRecorderPlayer", "File duration (ms): $actualDuration")
          android.util.Log.d("AudioRecorderPlayer", "File duration (seconds): ${actualDuration / 1000}")
          
          tempPlayer.release()
        } catch (e: Exception) {
          android.util.Log.e("AudioRecorderPlayer", "Error getting duration: ${e.message}")
          // If we can't get duration, use 0
          actualDuration = 0.0
        }
      }
      
      // Return an object with both file path and duration
      val result = Arguments.createMap()
      result.putString("filePath", filePath)
      result.putDouble("duration", actualDuration)
      promise.resolve(result)
      
      // Don't reset recording path - keep it for playback
    } catch (e: Exception) {
      promise.reject("stop_error", "Failed to stop recording: ${e.message}", e)
    }
  }

  // Playback methods
  override fun startPlayer(uri: String?, httpHeaders: ReadableMap?, promise: Promise) {
    try {
      // If no URI provided, try to play the last recorded file
      val fileUri = uri ?: recordingFilePath ?: run {
        promise.reject("invalid_uri", "No URI provided and no recording available", null)
        return
      }
      
      mediaPlayer = MediaPlayer().apply {
        when {
          fileUri.startsWith("http://") || fileUri.startsWith("https://") -> {
            val headers = httpHeaders?.let { headersMap ->
              val map = HashMap<String, String>()
              val iterator = headersMap.keySetIterator()
              while (iterator.hasNextKey()) {
                val key = iterator.nextKey()
                map[key] = headersMap.getString(key) ?: ""
              }
              map
            }
            setDataSource(reactContext, Uri.parse(fileUri), headers)
          }
          else -> {
            setDataSource(fileUri)
          }
        }
        
        setOnCompletionListener { mp ->
          stopPlayTimer()
          
          val finalDuration = mp.duration.toDouble()
          
          // Send final playback update to ensure progress reaches 100%
          if (hasPlayBackListener) {
            val finalParams = Arguments.createMap()
            finalParams.putDouble("currentPosition", finalDuration)
            finalParams.putDouble("duration", finalDuration)
            sendEvent("rn-playback", finalParams)
          }
          
          // Send playback-end event
          if (hasPlayBackListener) {
            val params = Arguments.createMap()
            params.putBoolean("finished", true)
            params.putDouble("duration", finalDuration)
            params.putDouble("currentPosition", finalDuration)
            sendEvent("rn-playback-end", params)
          }
        }
        
        prepare()
        
        // Debug: Log the actual duration when starting playback
        val actualDuration = duration.toDouble()
        android.util.Log.d("AudioRecorderPlayer", "=== START PLAYER ===")
        android.util.Log.d("AudioRecorderPlayer", "File URI: $fileUri")
        android.util.Log.d("AudioRecorderPlayer", "MediaPlayer duration (ms): $actualDuration")
        android.util.Log.d("AudioRecorderPlayer", "MediaPlayer duration (seconds): ${actualDuration / 1000}")
        
        start()
      }
      
      startPlayTimer()
      promise.resolve(fileUri)
    } catch (e: Exception) {
      promise.reject("player_error", "Failed to start player: ${e.message}", e)
    }
  }

  override fun stopPlayer(promise: Promise) {
    try {
      mediaPlayer?.apply {
        stop()
        release()
      }
      mediaPlayer = null
      stopPlayTimer()
      promise.resolve("Player stopped")
    } catch (e: Exception) {
      promise.reject("stop_error", "Failed to stop player: ${e.message}", e)
    }
  }

  override fun pausePlayer(promise: Promise) {
    try {
      mediaPlayer?.pause()
      stopPlayTimer()
      promise.resolve("Player paused")
    } catch (e: Exception) {
      promise.reject("pause_error", "Failed to pause player: ${e.message}", e)
    }
  }

  override fun resumePlayer(promise: Promise) {
    try {
      mediaPlayer?.start()
      startPlayTimer()
      promise.resolve("Player resumed")
    } catch (e: Exception) {
      promise.reject("resume_error", "Failed to resume player: ${e.message}", e)
    }
  }

  override fun seekToPlayer(time: Double, promise: Promise) {
    try {
      mediaPlayer?.seekTo(time.toInt())
      promise.resolve("Seek completed")
    } catch (e: Exception) {
      promise.reject("seek_error", "Failed to seek: ${e.message}", e)
    }
  }

  override fun setVolume(volume: Double, promise: Promise) {
    try {
      mediaPlayer?.setVolume(volume.toFloat(), volume.toFloat())
      promise.resolve("Volume set")
    } catch (e: Exception) {
      promise.reject("volume_error", "Failed to set volume: ${e.message}", e)
    }
  }

  override fun setPlaybackSpeed(speed: Double, promise: Promise) {
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        mediaPlayer?.playbackParams = mediaPlayer?.playbackParams?.setSpeed(speed.toFloat()) 
          ?: promise.reject("player_null", "Media player is null", null).let { return }
        promise.resolve("Playback speed set")
      } else {
        promise.reject("not_supported", "Playback speed is not supported on this Android version", null)
      }
    } catch (e: Exception) {
      promise.reject("speed_error", "Failed to set playback speed: ${e.message}", e)
    }
  }

  // Subscription
  override fun setSubscriptionDuration(sec: Double) {
    subscriptionDuration = (sec * 1000).toLong()
  }

  // Listeners
  override fun addRecordBackListener(callback: Callback) {
    hasRecordBackListener = true
    // Callback is only for compatibility, we use events instead
  }

  override fun removeRecordBackListener() {
    hasRecordBackListener = false
  }

  override fun addPlayBackListener(callback: Callback) {
    hasPlayBackListener = true
    // Callback is only for compatibility, we use events instead
  }

  override fun removePlayBackListener() {
    hasPlayBackListener = false
  }
  
  private fun sendEvent(eventName: String, params: WritableMap) {
    reactContext
      .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
      .emit(eventName, params)
  }

  // Utility methods
  override fun mmss(secs: Double): String {
    val seconds = secs.toInt()
    val minutes = seconds / 60
    val remainingSeconds = seconds % 60
    return String.format("%02d:%02d", minutes, remainingSeconds)
  }

  override fun mmssss(milisecs: Double): String {
    val totalSeconds = (milisecs / 1000).toInt()
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    val centiseconds = (milisecs.toInt() % 1000) / 10  // Convert to centiseconds (0-99)
    return String.format("%02d:%02d:%02d", minutes, seconds, centiseconds)
  }

  // Timer methods
  private fun startRecordTimer() {
    stopRecordTimer()
    recordTimer = Timer()
    recordTimer?.scheduleAtFixedRate(object : TimerTask() {
      override fun run() {
        if (hasRecordBackListener) {
          val currentTime = System.currentTimeMillis() - recordStartTime
          val params = Arguments.createMap()
          params.putDouble("currentPosition", currentTime.toDouble())
          params.putDouble("currentMetering", 0.0)
          params.putDouble("currentPeakMetering", 0.0)
          
          handler.post {
            sendEvent("rn-recordback", params)
          }
        }
      }
    }, 0, subscriptionDuration)
  }

  private fun stopRecordTimer() {
    recordTimer?.cancel()
    recordTimer = null
  }

  private fun startPlayTimer() {
    stopPlayTimer()
    playTimer = Timer()
    playTimer?.scheduleAtFixedRate(object : TimerTask() {
      override fun run() {
        if (hasPlayBackListener) {
          mediaPlayer?.let { player ->
            val currentPos = player.currentPosition.toDouble()
            val duration = player.duration.toDouble()
            
            val params = Arguments.createMap()
            params.putDouble("currentPosition", currentPos)
            params.putDouble("duration", duration)
            
            handler.post {
              sendEvent("rn-playback", params)
            }
            
            // Stop timer if playback has ended
            if (!player.isPlaying && duration > 0 && currentPos >= duration - 100) {
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

  companion object {
    const val NAME = "AudioRecorderPlayer"
  }
}