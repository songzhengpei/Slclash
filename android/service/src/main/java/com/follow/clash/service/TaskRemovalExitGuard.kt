package com.follow.clash.service

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import com.follow.clash.common.Phase4Mark
import com.follow.clash.common.TaskRemovalStopStore

internal fun isVendorTaskRemovalExit(description: String?): Boolean {
    val normalized = description.orEmpty().lowercase()
    return normalized.contains("swipeupclean") || normalized.contains("onekeyclean")
}

internal object TaskRemovalExitGuard {
    fun applyIfNeeded(context: Context, checkpoint: VpnRecoveryCheckpoint): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
        val activityManager = context.getSystemService(ActivityManager::class.java)
        val taskRemovalExit = runCatching {
            activityManager.getHistoricalProcessExitReasons(null, 0, 16).any { exit ->
                exit.timestamp > checkpoint.updatedAt && isVendorTaskRemovalExit(exit.description)
            }
        }.getOrDefault(false)
        if (!taskRemovalExit) return false

        TaskRemovalStopStore.mark(context)
        VpnRecoveryStore(context).clear()
        VpnRecoveryWatchdog.cancel(context)
        Phase4Mark.emit(
            "vpn_task_removed",
            mapOf("phase" to "detected_from_exit_history"),
        )
        return true
    }
}
