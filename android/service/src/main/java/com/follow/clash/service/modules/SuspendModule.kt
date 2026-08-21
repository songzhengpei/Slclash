package com.follow.clash.service.modules

import android.app.Service
import android.content.Intent
import android.os.PowerManager
import androidx.core.content.getSystemService
import com.follow.clash.common.Phase4Mark
import com.follow.clash.common.receiveBroadcastFlow
import com.follow.clash.core.Core
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onStart
import kotlinx.coroutines.launch


class SuspendModule(private val service: Service) : Module() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var job: Job? = null

    private fun isScreenOn(): Boolean {
        val pm = service.getSystemService<PowerManager>()
        return when (pm != null) {
            true -> pm.isInteractive
            false -> true
        }
    }

    val isDeviceIdleMode: Boolean
        get() {
            return service.getSystemService<PowerManager>()?.isDeviceIdleMode ?: true
        }

    private fun onUpdate(isScreenOn: Boolean) {
        val deviceIdle = isDeviceIdleMode
        Phase4Mark.emit("screen_state", mapOf("screen_on" to isScreenOn))
        Phase4Mark.emit("device_idle_state", mapOf("device_idle" to deviceIdle))
        if (isScreenOn) {
            Phase4Mark.emit("core_suspend_requested", mapOf("value" to false))
            Core.suspended(false)
            return
        }
        Phase4Mark.emit("core_suspend_requested", mapOf("value" to deviceIdle))
        Core.suspended(deviceIdle)
    }

    override suspend fun onInstall() {
        job = scope.launch {
            val screenFlow = service.receiveBroadcastFlow {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
            }.map { intent ->
                intent.action == Intent.ACTION_SCREEN_ON
            }.onStart {
                emit(isScreenOn())
            }

            screenFlow.collect {
                    onUpdate(it)
                }
        }
    }

    override suspend fun onUninstall() {
        job?.cancelAndJoin()
        job = null
        scope.cancel()
    }
}
