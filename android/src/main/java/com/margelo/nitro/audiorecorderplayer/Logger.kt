package com.margelo.nitro.audiorecorderplayer

import android.util.Log

/**
 * Simple logger that only logs in Debug builds.
 * Use Logger.d/i/w/e instead of Log.* to avoid logcat noise in Release.
 */
object Logger {
  private const val TAG = "NitroSound"

  @JvmStatic fun d(message: String, tr: Throwable? = null) {
    if (BuildConfig.DEBUG) {
      if (tr != null) Log.d(TAG, message, tr) else Log.d(TAG, message)
    }
  }

  @JvmStatic fun i(message: String, tr: Throwable? = null) {
    if (BuildConfig.DEBUG) {
      if (tr != null) Log.i(TAG, message, tr) else Log.i(TAG, message)
    }
  }

  @JvmStatic fun w(message: String, tr: Throwable? = null) {
    if (BuildConfig.DEBUG) {
      if (tr != null) Log.w(TAG, message, tr) else Log.w(TAG, message)
    }
  }

  @JvmStatic fun e(message: String, tr: Throwable? = null) {
    if (BuildConfig.DEBUG) {
      if (tr != null) Log.e(TAG, message, tr) else Log.e(TAG, message)
    }
  }
}

