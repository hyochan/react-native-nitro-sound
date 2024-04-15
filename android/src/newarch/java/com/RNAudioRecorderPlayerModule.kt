package com

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReadableMap

import com.dooboolab.audiorecorderplayer.NativeAudioRecorderPlayerSpec
import com.dooboolab.audiorecorderplayer.RNAudioRecorderPlayerModuleImpl

class RNAudioRecorderPlayerModule(reactContext: ReactApplicationContext) : NativeAudioRecorderPlayerSpec(reactContext) {
    private var implementation: RNAudioRecorderPlayerModuleImpl = RNAudioRecorderPlayerModuleImpl(reactContext)

    override fun getName() = NAME

    override fun startRecorder(uri: String, meteringEnabled: Boolean, audioSets: ReadableMap?, promise: Promise) {
        implementation.startRecorder(uri, meteringEnabled, audioSets, promise)
    }

    override fun resumeRecorder(promise: Promise) {
        implementation.resumeRecorder(promise)
    }

    override fun pauseRecorder(promise: Promise) {
        implementation.pauseRecorder(promise)
    }

    override fun stopRecorder(promise: Promise) {
        implementation.stopRecorder(promise)
    }

    override fun setVolume(volume: Double, promise: Promise) {
        implementation.setVolume(volume, promise)
    }

    override fun startPlayer(uri: String, httpHeaders: ReadableMap?, promise: Promise) {
        implementation.startPlayer(uri, httpHeaders, promise)
    }

    override fun resumePlayer(promise: Promise) {
        implementation.resumePlayer(promise)
    }

    override fun pausePlayer(promise: Promise) {
        implementation.pausePlayer(promise)
    }

    override fun seekToPlayer(time: Double, promise: Promise) {
        implementation.seekToPlayer(time, promise)
    }

    override fun stopPlayer(promise: Promise) {
        implementation.stopPlayer(promise)
    }

    override fun setSubscriptionDuration(sec: Double, promise: Promise) {
        implementation.setSubscriptionDuration(sec, promise)
    }
}
