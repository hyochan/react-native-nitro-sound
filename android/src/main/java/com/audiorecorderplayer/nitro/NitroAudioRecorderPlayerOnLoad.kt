package com.audiorecorderplayer.nitro

import com.facebook.react.bridge.ReactApplicationContext
import com.margelo.nitro.NitroModules

class NitroAudioRecorderPlayerOnLoad {
    companion object {
        @JvmStatic
        fun load(context: ReactApplicationContext) {
            NitroModules.register(HybridAudioRecorderPlayer::class.java) { 
                HybridAudioRecorderPlayer(context)
            }
        }
    }
}