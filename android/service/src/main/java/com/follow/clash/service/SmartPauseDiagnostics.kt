package com.follow.clash.service

import android.content.Context
import android.os.PowerManager
import android.os.Process
import android.os.SystemClock
import com.follow.clash.common.Phase4Mark
import com.follow.clash.service.modules.PhysicalNetworkSnapshot

internal data class SmartPauseDiagnosticEntry(
    val timestamp: Long,
    val elapsedRealtime: Long,
    val processId: Int,
    val sessionId: Long,
    val reason: String,
    val runtimeState: String,
    val previousDesiredState: SmartPauseDesiredState?,
    val desiredState: SmartPauseDesiredState,
    val networkState: SmartPausePhysicalNetwork,
    val networkTransport: String,
    val networkId: Long?,
    val trusted: Boolean,
    val networkGeneration: Long,
    val screenInteractive: Boolean?,
    val deviceIdle: Boolean?,
    val action: SmartPauseAction,
)

internal class BoundedRingBuffer<T>(private val capacity: Int) {
    init {
        require(capacity > 0)
    }

    private val values = ArrayDeque<T>(capacity)

    @Synchronized
    fun add(value: T) {
        if (values.size == capacity) values.removeFirst()
        values.addLast(value)
    }

    @Synchronized
    fun snapshot(): List<T> = values.toList()
}

internal object SmartPauseDiagnostics {
    private val entries = BoundedRingBuffer<SmartPauseDiagnosticEntry>(100)

    fun record(
        context: Context,
        sessionId: Long,
        reason: String,
        runtimeState: String,
        previousDesiredState: SmartPauseDesiredState?,
        desiredState: SmartPauseDesiredState,
        networkState: SmartPausePhysicalNetwork,
        network: PhysicalNetworkSnapshot?,
        trusted: Boolean,
        action: SmartPauseAction,
    ) {
        val power = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val entry = SmartPauseDiagnosticEntry(
            timestamp = System.currentTimeMillis(),
            elapsedRealtime = SystemClock.elapsedRealtime(),
            processId = Process.myPid(),
            sessionId = sessionId,
            reason = reason,
            runtimeState = runtimeState,
            previousDesiredState = previousDesiredState,
            desiredState = desiredState,
            networkState = networkState,
            networkTransport = network?.transport ?: "unknown",
            networkId = network?.networkId,
            trusted = trusted,
            networkGeneration = network?.generation ?: 0L,
            screenInteractive = power?.isInteractive,
            deviceIdle = power?.isDeviceIdleMode,
            action = action,
        )
        entries.add(entry)
        Phase4Mark.emit(
            "smart_pause_reconcile",
            mapOf(
                "reason" to reason,
                "session_state" to runtimeState,
                "session_id" to sessionId,
                "previous_desired" to previousDesiredState?.name,
                "desired" to desiredState.name,
                "network_state" to networkState.name,
                "network_type" to entry.networkTransport,
                "network_id" to entry.networkId,
                "trusted" to trusted,
                "network_generation" to entry.networkGeneration,
                "screen_interactive" to entry.screenInteractive,
                "device_idle" to entry.deviceIdle,
                "action" to action.name,
            ),
        )
    }

    fun snapshot(): List<SmartPauseDiagnosticEntry> = entries.snapshot()
}
