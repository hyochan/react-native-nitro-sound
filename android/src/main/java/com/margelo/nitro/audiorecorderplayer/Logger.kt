package com.margelo.nitro.audiorecorderplayer

import android.util.Log
import com.margelo.nitro.sound.BuildConfig

/**
 * Simple logger that only logs in Debug builds.
 * Use Logger.d/i/w/e instead of Log.* to avoid logcat noise in Release.
 */
object Logger {
  private const val TAG = "NitroSound"

  @JvmStatic fun d(message: String, tr: Throwable? = null) {
    log(Log.DEBUG, message, tr)
  }

  @JvmStatic fun i(message: String, tr: Throwable? = null) {
    log(Log.INFO, message, tr)
  }

  @JvmStatic fun w(message: String, tr: Throwable? = null) {
    log(Log.WARN, message, tr)
  }

  @JvmStatic fun e(message: String, tr: Throwable? = null) {
    log(Log.ERROR, message, tr)
  }

  private fun log(priority: Int, message: String, tr: Throwable?) {
    if (!BuildConfig.DEBUG) return
    val fullMessage = if (tr != null) {
      "$message\n${'$'}{Log.getStackTraceString(tr)}"
    } else message
    Log.println(priority, TAG, fullMessage)
  }
}
