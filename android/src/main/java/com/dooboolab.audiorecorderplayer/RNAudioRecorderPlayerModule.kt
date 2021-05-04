package com.dooboolab.audiorecorderplayer

import android.Manifest
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.core.app.ActivityCompat
import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule.RCTDeviceEventEmitter
import com.facebook.react.modules.core.PermissionListener
import java.io.IOException
import java.util.*
import kotlin.math.log10

class RNAudioRecorderPlayerModule(private val reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext), PermissionListener {
    private var audioFileURL = ""
    private var subsDurationMillis = 100
    private var _meteringEnabled = false
    private var mediaRecorder: MediaRecorder? = null
    private var mediaPlayer: MediaPlayer? = null
    private var recorderRunnable: Runnable? = null
    private var mTask: TimerTask? = null
    private var mTimer: Timer? = null
    var recordHandler: Handler? = Handler(Looper.getMainLooper())
    override fun getName(): String {
        return tag
    }

    @ReactMethod
    fun startRecorder(path: String, meteringEnabled: Boolean, audioSet: ReadableMap?, promise: Promise) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                    ActivityCompat.checkSelfPermission(reactContext, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED &&
                    ActivityCompat.checkSelfPermission(reactContext, Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions((currentActivity)!!, arrayOf(
                        Manifest.permission.RECORD_AUDIO,
                        Manifest.permission.WRITE_EXTERNAL_STORAGE), 0)
                promise.reject("No permission granted.", "Try again after adding permission.")
                return
            }
        } catch (ne: NullPointerException) {
            Log.w(tag, ne.toString())
            promise.reject("No permission granted.", "Try again after adding permission.")
            return
        }
        audioFileURL = if (((path == "DEFAULT"))) fileLocation else path
        _meteringEnabled = meteringEnabled
        if (mediaRecorder == null) {
            mediaRecorder = MediaRecorder()
        }
        if (audioSet != null) {
            mediaRecorder!!.setAudioSource(if (audioSet.hasKey("AudioSourceAndroid")) audioSet.getInt("AudioSourceAndroid") else MediaRecorder.AudioSource.MIC)
            mediaRecorder!!.setOutputFormat(if (audioSet.hasKey("OutputFormatAndroid")) audioSet.getInt("OutputFormatAndroid") else MediaRecorder.OutputFormat.MPEG_4)
            mediaRecorder!!.setAudioEncoder(if (audioSet.hasKey("AudioEncoderAndroid")) audioSet.getInt("AudioEncoderAndroid") else MediaRecorder.AudioEncoder.AAC)
            mediaRecorder!!.setAudioSamplingRate(if (audioSet.hasKey("AudioSamplingRateAndroid")) audioSet.getInt("AudioSamplingRateAndroid") else 48000)
            mediaRecorder!!.setAudioEncodingBitRate(if (audioSet.hasKey("AudioEncodingBitRateAndroid")) audioSet.getInt("AudioEncodingBitRateAndroid") else 128000)
        } else {
            mediaRecorder!!.setAudioSource(MediaRecorder.AudioSource.MIC)
            mediaRecorder!!.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            mediaRecorder!!.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            mediaRecorder!!.setAudioEncodingBitRate(128000)
            mediaRecorder!!.setAudioSamplingRate(48000)
        }
        mediaRecorder!!.setOutputFile(audioFileURL)
        try {
            mediaRecorder!!.prepare()
            mediaRecorder!!.start()
            val systemTime = SystemClock.elapsedRealtime()
            recorderRunnable = object : Runnable {
                override fun run() {
                    val time = SystemClock.elapsedRealtime() - systemTime
                    val obj = Arguments.createMap()
                    obj.putDouble("current_position", time.toDouble())
                    if (_meteringEnabled) {
                        var maxAmplitude = 0
                        if (mediaRecorder != null) {
                            maxAmplitude = mediaRecorder!!.maxAmplitude
                        }
                        var dB = -160.0
                        val maxAudioSize = 32767.0
                        if (maxAmplitude > 0) {
                            dB = 20 * log10(maxAmplitude / maxAudioSize)
                        }
                        obj.putInt("current_metering", dB.toInt())
                    }
                    sendEvent(reactContext, "rn-recordback", obj)
                    recordHandler!!.postDelayed(this, subsDurationMillis.toLong())
                }
            }
            (recorderRunnable as Runnable).run()
            promise.resolve("file:///$audioFileURL")
        } catch (e: Exception) {
            Log.e(tag, "Exception: ", e)
            promise.reject("startRecord", e.message)
        }
    }

    @ReactMethod
    fun stopRecorder(promise: Promise) {
        if (recordHandler != null) {
            recordHandler!!.removeCallbacks(recorderRunnable)
        }
        if (mediaRecorder == null) {
            promise.reject("stopRecord", "recorder is null.")
            return
        }
        try {
            mediaRecorder!!.stop()
        } catch (stopException: RuntimeException) {
            Log.d(tag, stopException.message)
            promise.reject("stopRecord", stopException.message)
        }
        mediaRecorder!!.release()
        mediaRecorder = null
        promise.resolve("file:///$audioFileURL")
    }

    @ReactMethod
    fun setVolume(volume: Double, promise: Promise) {
        if (mediaPlayer == null) {
            promise.reject("setVolume", "player is null.")
            return
        }
        val mVolume = volume.toFloat()
        mediaPlayer!!.setVolume(mVolume, mVolume)
        promise.resolve("set volume")
    }

    @ReactMethod
    fun startPlayer(path: String, httpHeaders: ReadableMap?, promise: Promise) {
        if (mediaPlayer != null) {
            val isPaused = !mediaPlayer!!.isPlaying && mediaPlayer!!.currentPosition > 1
            if (isPaused) {
                mediaPlayer!!.start()
                promise.resolve("player resumed.")
                return
            }
            Log.e(tag, "Player is already running. Stop it first.")
            promise.reject("startPlay", "Player is already running. Stop it first.")
            return
        } else {
            mediaPlayer = MediaPlayer()
        }

        try {
            if ((path == "DEFAULT")) {
                mediaPlayer!!.setDataSource(fileLocation)
            } else {
                if (httpHeaders != null) {
                    val headers: MutableMap<String, String?> = HashMap<String, String?>()
                    val iterator = httpHeaders.keySetIterator()
                    while (iterator.hasNextKey()) {
                        val key = iterator.nextKey()
                        headers.put(key, httpHeaders.getString(key))
                    }
                    mediaPlayer!!.setDataSource(currentActivity!!.applicationContext, Uri.parse(path), headers)
                } else {
                    mediaPlayer!!.setDataSource(path)
                }
            }
            mediaPlayer!!.setOnPreparedListener { mp ->
                Log.d(tag, "mediaplayer prepared and start")
                mp.start()
                /**
                 * Set timer task to send event to RN.
                 */
                mTask = object : TimerTask() {
                    override fun run() {
                        val obj = Arguments.createMap()
                        obj.putInt("duration", mp.duration)
                        obj.putInt("current_position", mp.currentPosition)
                        sendEvent(reactContext, "rn-playback", obj)
                    }
                }
                mTimer = Timer()
                mTimer!!.schedule(mTask, 0, subsDurationMillis.toLong())
                val resolvedPath = if (((path == "DEFAULT"))) "file:///$fileLocation" else path
                promise.resolve(resolvedPath)
            }

            /**
             * Detect when finish playing.
             */
            mediaPlayer!!.setOnCompletionListener { mp ->
                /**
                 * Send last event
                 */
                val obj = Arguments.createMap()
                obj.putInt("duration", mp.duration)
                obj.putInt("current_position", mp.duration)
                sendEvent(reactContext, "rn-playback", obj)
                /**
                 * Reset player.
                 */
                Log.d(tag, "Plays completed.")
                mTimer!!.cancel()
                mp.stop()
                mp.release()
                mediaPlayer = null
            }
            mediaPlayer!!.prepare()
        } catch (e: IOException) {
            Log.e(tag, "startPlay() io exception")
            promise.reject("startPlay", e.message)
        } catch (e: NullPointerException) {
            Log.e(tag, "startPlay() null exception")
        }
    }

    @ReactMethod
    fun resumePlayer(promise: Promise) {
        if (mediaPlayer == null) {
            promise.reject("resume", "mediaPlayer is null.")
            return
        }
        if (mediaPlayer!!.isPlaying) {
            promise.reject("resume", "mediaPlayer is already running.")
            return
        }
        try {
            mediaPlayer!!.seekTo(mediaPlayer!!.currentPosition)
            mediaPlayer!!.start()
            promise.resolve("resume player")
        } catch (e: Exception) {
            Log.e(tag, "mediaPlayer resume: " + e.message)
            promise.reject("resume", e.message)
        }
    }

    @ReactMethod
    fun pausePlayer(promise: Promise) {
        if (mediaPlayer == null) {
            promise.reject("pausePlay", "mediaPlayer is null.")
            return
        }
        try {
            mediaPlayer!!.pause()
            promise.resolve("pause player")
        } catch (e: Exception) {
            Log.e(tag, "pausePlay exception: " + e.message)
            promise.reject("pausePlay", e.message)
        }
    }

    @ReactMethod
    fun seekToPlayer(time: Int, promise: Promise) {
        if (mediaPlayer == null) {
            promise.reject("seekTo", "mediaPlayer is null.")
            return
        }
        val millis = time * 1000
        mediaPlayer!!.seekTo(millis)
        promise.resolve("pause player")
    }

    private fun sendEvent(reactContext: ReactContext,
                          eventName: String,
                          params: WritableMap?) {
        reactContext
                .getJSModule<RCTDeviceEventEmitter>(RCTDeviceEventEmitter::class.java)
                .emit(eventName, params)
    }

    @ReactMethod
    fun stopPlayer(promise: Promise) {
        if (mTimer != null) {
            mTimer!!.cancel()
        }

        if (mediaPlayer == null) {
            promise.reject("stopPlay", "mediaPlayer is null.")
            return
        }

        try {
            mediaPlayer!!.release()
            mediaPlayer = null
            promise.resolve("stopped player")
        } catch (e: Exception) {
            Log.e(tag, "stopPlay exception: " + e.message)
            promise.reject("stopPlay", e.message)
        }
    }

    @ReactMethod
    fun setSubscriptionDuration(sec: Double, promise: Promise) {
        subsDurationMillis = (sec * 1000).toInt()
        promise.resolve("setSubscriptionDuration: $subsDurationMillis")
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray): Boolean {
        var requestRecordAudioPermission: Int = 200
        when (requestCode) {
            requestRecordAudioPermission -> if (grantResults[0] == PackageManager.PERMISSION_GRANTED) return true
        }
        return false
    }

    companion object {
        private var tag = "RNAudioRecorderPlayer"
        private var fileLocation = "sdcard/sound.mp4"
    }
}