package com.follow.clash.common

import android.os.Process
import android.os.SystemClock
import android.util.Log

/** Observer-only native companion to Dart StartupTrace for Phase 4 evidence. */
object Phase4Mark {
    private const val TAG = "Phase4Lifecycle"

    private fun enabled(): Boolean {
        val packageName = runCatching { GlobalState.application.packageName }.getOrNull()
            ?: return false
        return packageName.endsWith(".profile") || packageName.endsWith(".dev")
    }

    fun emit(name: String, extras: Map<String, Any?> = emptyMap()) {
        if (!enabled()) return
        val suffix = buildString {
            append(" pid=")
            append(Process.myPid())
            extras.forEach { (key, value) ->
                append(' ')
                append(key)
                append('=')
                append(token(value))
            }
        }
        Log.i(TAG, "[PHASE4] mark=$name elapsed_ms=${SystemClock.elapsedRealtime()}$suffix")
    }

    private fun token(value: Any?): String = when (value) {
        null -> "null"
        else -> value.toString().replace(Regex("\\s+"), "_")
    }
}
