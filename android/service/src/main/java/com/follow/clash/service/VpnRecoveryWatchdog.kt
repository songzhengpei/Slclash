package com.follow.clash.service

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat
import com.follow.clash.common.Phase4Mark
import com.follow.clash.common.TaskRemovalStopStore

internal fun shouldTriggerVpnWatchdogRecovery(
    taskRemovalStopRequested: Boolean,
    checkpointValid: Boolean,
): Boolean = !taskRemovalStopRequested && checkpointValid

internal object VpnRecoveryWatchdog {
    const val HEARTBEAT_INTERVAL_MILLIS = 15_000L
    private const val RECOVERY_DEADLINE_MILLIS = 45_000L
    private const val REQUEST_CODE = 0x564E
    internal const val ACTION_RECOVER = "com.follow.clash.service.action.WATCHDOG_RECOVER_VPN"

    private fun pendingIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        REQUEST_CODE,
        Intent(context, VpnRecoveryReceiver::class.java).setAction(ACTION_RECOVER),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    fun arm(context: Context): Boolean = runCatching {
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val triggerAt = System.currentTimeMillis() + RECOVERY_DEADLINE_MILLIS
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAt,
                pendingIntent(context),
            )
        } else {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAt,
                pendingIntent(context),
            )
        }
    }.isSuccess

    fun cancel(context: Context) {
        runCatching {
            context.getSystemService(AlarmManager::class.java).cancel(pendingIntent(context))
        }
    }
}

class VpnRecoveryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != VpnRecoveryWatchdog.ACTION_RECOVER) return
        val checkpoint = VpnRecoveryStore(context).readValid()
        if (checkpoint != null && TaskRemovalExitGuard.applyIfNeeded(context, checkpoint)) return
        val checkpointValid = checkpoint != null
        val taskRemovalStopRequested = TaskRemovalStopStore.isRequested(context)
        if (!shouldTriggerVpnWatchdogRecovery(taskRemovalStopRequested, checkpointValid)) {
            VpnRecoveryWatchdog.cancel(context)
            return
        }

        // Re-arm before dispatch so another process death during recovery still
        // has a durable wake-up path.
        VpnRecoveryWatchdog.arm(context)
        val dispatched = runCatching {
            ContextCompat.startForegroundService(
                context,
                Intent(context, VpnService::class.java).setAction(VpnRecoveryWatchdog.ACTION_RECOVER),
            )
        }.isSuccess
        Phase4Mark.emit(
            "vpn_recovery_watchdog",
            mapOf("operation" to "fire", "dispatched" to dispatched),
        )
    }
}
