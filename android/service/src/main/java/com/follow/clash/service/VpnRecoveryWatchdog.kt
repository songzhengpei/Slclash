package com.follow.clash.service

import android.app.AlarmManager
import android.app.PendingIntent
import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock

internal fun nextWatchdogTriggerAt(now: Long, deadlineMillis: Long): Long = now + deadlineMillis

internal object VpnRecoveryWatchdog {
    const val HEARTBEAT_INTERVAL_MILLIS = 10_000L
    internal const val RECOVERY_DEADLINE_MILLIS = 15_000L
    internal const val JOB_ID = 0x564E
    private const val REQUEST_CODE_ELAPSED = 0x564E
    private const val REQUEST_CODE_RTC = 0x564F
    internal const val ACTION_RECOVER = "com.follow.clash.service.action.WATCHDOG_RECOVER_VPN"

    private fun pendingIntent(context: Context, requestCode: Int): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            requestCode,
            Intent(context, VpnRecoveryReceiver::class.java).setAction(ACTION_RECOVER),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun scheduleExact(
        alarmManager: AlarmManager,
        type: Int,
        triggerAt: Long,
        pendingIntent: PendingIntent,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()) {
            alarmManager.setExactAndAllowWhileIdle(type, triggerAt, pendingIntent)
        } else {
            alarmManager.setAndAllowWhileIdle(type, triggerAt, pendingIntent)
        }
    }

    private fun armAlarms(context: Context): Boolean = runCatching {
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        scheduleExact(
            alarmManager,
            AlarmManager.ELAPSED_REALTIME_WAKEUP,
            nextWatchdogTriggerAt(SystemClock.elapsedRealtime(), RECOVERY_DEADLINE_MILLIS),
            pendingIntent(context, REQUEST_CODE_ELAPSED),
        )
        scheduleExact(
            alarmManager,
            AlarmManager.RTC_WAKEUP,
            nextWatchdogTriggerAt(System.currentTimeMillis(), RECOVERY_DEADLINE_MILLIS),
            pendingIntent(context, REQUEST_CODE_RTC),
        )
    }.isSuccess

    private fun armJob(context: Context): Boolean = runCatching {
        val scheduler = context.getSystemService(JobScheduler::class.java) ?: return false
        val job = JobInfo.Builder(
            JOB_ID,
            ComponentName(context, VpnRecoveryJobService::class.java),
        )
            .setMinimumLatency(RECOVERY_DEADLINE_MILLIS)
            .setOverrideDeadline(RECOVERY_DEADLINE_MILLIS)
            .build()
        scheduler.schedule(job) == JobScheduler.RESULT_SUCCESS
    }.getOrDefault(false)

    fun arm(context: Context): Boolean {
        val alarmsArmed = armAlarms(context)
        val jobArmed = armJob(context)
        return alarmsArmed || jobArmed
    }

    fun cancel(context: Context) {
        runCatching {
            val alarmManager = context.getSystemService(AlarmManager::class.java)
            alarmManager.cancel(pendingIntent(context, REQUEST_CODE_ELAPSED))
            alarmManager.cancel(pendingIntent(context, REQUEST_CODE_RTC))
        }
        runCatching {
            context.getSystemService(JobScheduler::class.java)?.cancel(JOB_ID)
        }
    }
}

class VpnRecoveryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != VpnRecoveryWatchdog.ACTION_RECOVER) return
        VpnProcessRecovery.request(context, "watchdog")
    }
}
