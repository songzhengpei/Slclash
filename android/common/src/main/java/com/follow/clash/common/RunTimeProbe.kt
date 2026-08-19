package com.follow.clash.common

import android.app.ActivityManager
import android.content.Context

/**
 * Idle cold-start should not bind/start `:remote` just to learn that VPN is down.
 * Bind only when a session might already exist.
 */
object RunTimeProbe {
    fun shouldBindForRunTime(
        remoteProcessAlive: Boolean,
        alreadyBound: Boolean,
        cachedRunTime: Long,
    ): Boolean {
        if (cachedRunTime > 0L || alreadyBound) return true
        return remoteProcessAlive
    }

    fun isRemoteProcessAlive(context: Context): Boolean {
        val am =
            context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                ?: return false
        val remoteName = "${context.packageName}:remote"
        return am.runningAppProcesses?.any { it.processName == remoteName } == true
    }
}
