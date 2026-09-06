package com.follow.clash.service

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import com.follow.clash.common.GlobalState
import com.follow.clash.common.Phase4Mark
import com.follow.clash.common.TaskRemovalStopStore

internal fun shouldRequestVpnProcessRecovery(
    taskRemovalStopRequested: Boolean,
    checkpointValid: Boolean,
): Boolean = !taskRemovalStopRequested && checkpointValid

object VpnProcessRecovery {
    fun request(context: Context, reason: String): Boolean {
        val app = context.applicationContext
        val checkpoint = VpnRecoveryStore(app).readValid()
        if (checkpoint != null && TaskRemovalExitGuard.applyIfNeeded(app, checkpoint)) {
            return false
        }
        val checkpointValid = checkpoint != null
        val taskRemovalStopRequested = TaskRemovalStopStore.isRequested(app)
        if (!shouldRequestVpnProcessRecovery(taskRemovalStopRequested, checkpointValid)) {
            VpnRecoveryWatchdog.cancel(app)
            return false
        }

        // Re-arm first so another death during this dispatch still has a
        // durable wake-up. Starting VpnService is what actually rebuilds TUN.
        VpnRecoveryWatchdog.arm(app)
        val dispatched = startVpnService(app)
        Phase4Mark.emit(
            "vpn_process_recovery_request",
            mapOf("reason" to reason, "dispatched" to dispatched),
        )
        GlobalState.log("VPN process recovery requested reason=$reason dispatched=$dispatched")
        return dispatched
    }

    internal fun startVpnService(context: Context): Boolean = runCatching {
        ContextCompat.startForegroundService(
            context,
            Intent(context, VpnService::class.java).setAction(VpnRecoveryWatchdog.ACTION_RECOVER),
        )
    }.isSuccess
}
