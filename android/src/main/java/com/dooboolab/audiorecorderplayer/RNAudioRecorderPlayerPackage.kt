package com.dooboolab.audiorecorderplayer

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager
import com.audiorecorderplayer.nitro.NitroAudioRecorderPlayerOnLoad

class RNAudioRecorderPlayerPackage : ReactPackage {
    override fun createNativeModules(reactContext: ReactApplicationContext): List<NativeModule> {
        // Load Nitro module
        NitroAudioRecorderPlayerOnLoad.load(reactContext)
        return emptyList()
    }

    override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> {
        return emptyList()
    }
}