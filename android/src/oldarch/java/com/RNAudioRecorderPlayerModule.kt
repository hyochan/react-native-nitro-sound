package com

import com.dooboolab.audiorecorderplayer.RNAudioRecorderPlayerModuleImpl
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap

class RNAudioRecorderPlayerModule(context: ReactApplicationContext) : ReactContextBaseJavaModule(context) {
    private var implementation: RNAudioRecorderPlayerModuleImpl = RNAudioRecorderPlayerModuleImpl(context)

    override fun getName(): String = RNAudioRecorderPlayerModuleImpl.TAG

    @ReactMethod
    fun startRecorder(path: String, audioSet: ReadableMap?, meteringEnabled: Boolean, promise: Promise) {
        implementation.startRecorder(path, audioSet, meteringEnabled, promise)
    }
    @ReactMethod
    fun resumeRecorder(promise: Promise) {
        implementation.resumeRecorder(promise)
    }

    @ReactMethod
    fun pauseRecorder(promise: Promise) {
        implementation.pauseRecorder(promise)
    }

    @ReactMethod
    fun stopRecorder(promise: Promise) {
        implementation.stopRecorder(promise)
    }

    @ReactMethod
    fun setVolume(volume: Double, promise: Promise) {
        implementation.setVolume(volume, promise)
    }

    @ReactMethod
    fun startPlayer(path: String, httpHeaders: ReadableMap?, promise: Promise) {
        implementation.startPlayer(path, httpHeaders, promise)
    }

    @ReactMethod
    fun resumePlayer(promise: Promise) {
        implementation.resumePlayer(promise)
    }

    @ReactMethod
    fun pausePlayer(promise: Promise) {
        implementation.pausePlayer(promise)
    }

    @ReactMethod
    fun seekToPlayer(time: Double, promise: Promise) {
        implementation.seekToPlayer(time, promise)
    }

    @ReactMethod
    fun stopPlayer(promise: Promise) {
        implementation.stopPlayer(promise)
    }

    @ReactMethod
    fun setSubscriptionDuration(sec: Double, promise: Promise) {
        implementation.setSubscriptionDuration(sec, promise)
    }
}