package com.dooboolab.audiorecorderplayer

import com.facebook.react.TurboReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider

class RNAudioRecorderPlayerPackage : TurboReactPackage() {

    override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? =
      if (name == RNAudioRecorderPlayerModuleImpl.TAG) {
        RNAudioRecorderPlayerModule(reactContext)
      } else {
        null
     }

    override fun getReactModuleInfoProvider() = ReactModuleInfoProvider {
      val isTurboModule = BuildConfig.IS_NEW_ARCHITECTURE_ENABLED

      mapOf(
        RNAudioRecorderPlayerModuleImpl.TAG to ReactModuleInfo(
        RNAudioRecorderPlayerModuleImpl.TAG,
        RNAudioRecorderPlayerModuleImpl.TAG,
        false,
        false,
        false,
        false,
         isTurboModule
        )
      )
    }
}