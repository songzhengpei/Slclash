package com.follow.clash

import android.net.VpnService
import com.follow.clash.common.GlobalState
import com.follow.clash.common.Phase4Mark
import com.follow.clash.models.SharedState
import com.follow.clash.plugins.AppPlugin
import com.follow.clash.plugins.TilePlugin
import com.follow.clash.service.models.NotificationParams
import com.follow.clash.service.models.SessionSnapshot
import com.follow.clash.service.models.SessionState
import com.google.gson.Gson
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

enum class RunState {
    START, PENDING, STOP
}

internal fun runStateForSessionState(state: String): RunState = when (state) {
    SessionState.RUNNING -> RunState.START
    SessionState.STARTING, SessionState.STOPPING -> RunState.PENDING
    SessionState.PAUSED, SessionState.STOPPED -> RunState.STOP
    else -> RunState.STOP
}

internal enum class SessionCommand {
    START, STOP, SMART_RESUME, NONE
}

internal fun toggleCommandForSessionState(state: String): SessionCommand = when (state) {
    SessionState.RUNNING -> SessionCommand.STOP
    SessionState.PAUSED -> SessionCommand.SMART_RESUME
    SessionState.STOPPED -> SessionCommand.START
    else -> SessionCommand.NONE
}

internal fun canFullStopSession(state: String): Boolean =
    state == SessionState.RUNNING || state == SessionState.PAUSED


object State {

    val runLock = Mutex()

    var runTime: Long = 0

    var sessionSnapshot: SessionSnapshot = SessionSnapshot.stopped()

    var sharedState: SharedState = SharedState()

    val runStateFlow: MutableStateFlow<RunState> = MutableStateFlow(RunState.STOP)

    var flutterEngine: FlutterEngine? = null

    val appPlugin: AppPlugin?
        get() = flutterEngine?.plugin<AppPlugin>()

    val tilePlugin: TilePlugin?
        get() = flutterEngine?.plugin<TilePlugin>()

    suspend fun handleToggleAction() {
        handleSyncState()
        Phase4Mark.emit(
            "vpn_action_requested",
            mapOf("action" to "toggle", "source" to "temp_activity", "run_state" to runStateFlow.value),
        )
        var action: (suspend () -> Unit)?
        runLock.withLock {
            action = when (toggleCommandForSessionState(sessionSnapshot.state)) {
                SessionCommand.STOP -> ::handleStopServiceAction
                SessionCommand.SMART_RESUME -> ::handleSmartResumeAction
                SessionCommand.START -> ::handleStartServiceAction
                SessionCommand.NONE -> null
            }
        }
        action?.invoke()
    }

    suspend fun handleSmartStopAction() {
        Phase4Mark.emit(
            "vpn_action_requested",
            mapOf("action" to "smart_stop", "source" to "temp_activity", "run_state" to runStateFlow.value),
        )
        if (flutterEngine != null) {
            tilePlugin?.handleSmartStop()
            return
        }
        Service.bind()
        Service.smartStop()
        handleSyncState()
    }

    suspend fun handleSmartResumeAction() {
        Phase4Mark.emit(
            "vpn_action_requested",
            mapOf("action" to "smart_resume", "source" to "temp_activity", "run_state" to runStateFlow.value),
        )
        if (flutterEngine != null) {
            tilePlugin?.handleSmartResume()
            return
        }
        Service.bind()
        Service.smartResume()
        handleSyncState()
    }

    suspend fun handleSyncState() {
        runLock.withLock {
            Service.bind()
            Service.getSessionSnapshot()
                .onSuccess(::applySnapshot)
                .onFailure { GlobalState.log("Session snapshot unavailable: ${it.message}") }
        }
    }

    private fun applySnapshot(snapshot: SessionSnapshot) {
        sessionSnapshot = snapshot
        runTime = snapshot.takeIf { it.state == SessionState.RUNNING }?.startedAt ?: 0L
        val runState = runStateForSessionState(snapshot.state)
        Phase4Mark.emit(
            "vpn_snapshot",
            mapOf(
                "layer" to "android_app",
                "state" to snapshot.state,
                "session_id" to snapshot.sessionId,
                "started_at" to snapshot.startedAt,
                "smart_paused" to snapshot.smartPaused,
                "run_state" to runState,
                "run_time" to runTime,
            ),
        )
        runStateFlow.tryEmit(runState)
    }

    suspend fun handleStartServiceAction() {
        Phase4Mark.emit(
            "vpn_action_requested",
            mapOf("action" to "start", "source" to "android_action", "run_state" to runStateFlow.value),
        )
        if (runStateFlow.value != RunState.STOP) {
            return
        }
        tilePlugin?.handleStart()
        if (flutterEngine != null) {
            return
        }
        startServiceWithPref()
    }

    suspend fun handleStopServiceAction() {
        handleSyncState()
        Phase4Mark.emit(
            "vpn_action_requested",
            mapOf("action" to "stop", "source" to "android_action", "run_state" to runStateFlow.value),
        )
        if (!canFullStopSession(sessionSnapshot.state)) {
            return
        }
        tilePlugin?.handleStop()
        if (flutterEngine != null) {
            return
        }
        GlobalState.application.showToast(sharedState.stopTip)
        handleStopService()
    }

    suspend fun handleStartService(): Boolean {
        // Short-lock: check + set PENDING, then release lock for permission wait
        runLock.withLock {
            if (runStateFlow.value != RunState.STOP) {
                return runStateFlow.value == RunState.START
            }
            runStateFlow.tryEmit(RunState.PENDING)
        }
        // Lock released — wait for permissions without blocking other operations
        try {
            val options = sharedState.vpnOptions
            if (options == null) {
                runLock.withLock {
                    runTime = 0L
                    runStateFlow.tryEmit(RunState.STOP)
                }
                return false
            }

            val appPlugin = flutterEngine?.plugin<AppPlugin>()
            if (appPlugin != null) {
                Phase4Mark.emit("vpn_permission_begin", mapOf("permission" to "notification"))
                val notificationReady = appPlugin.requestNotificationsPermissionAwait()
                Phase4Mark.emit(
                    "vpn_permission_result",
                    mapOf("permission" to "notification", "granted" to notificationReady),
                )
                if (!notificationReady) {
                    // 通知权限拒绝不阻断启动，继续
                }
                Phase4Mark.emit("vpn_permission_begin", mapOf("permission" to "vpn"))
                val vpnPrepared = appPlugin.prepareVpnAwait(options.enable)
                Phase4Mark.emit(
                    "vpn_permission_result",
                    mapOf("permission" to "vpn", "granted" to vpnPrepared),
                )
                if (!vpnPrepared) {
                    runLock.withLock {
                        if (runStateFlow.value == RunState.PENDING) {
                            runTime = 0L
                            runStateFlow.tryEmit(RunState.STOP)
                        }
                    }
                    return false
                }
            } else {
                Phase4Mark.emit("vpn_permission_begin", mapOf("permission" to "vpn"))
                val intent = VpnService.prepare(GlobalState.application)
                Phase4Mark.emit(
                    "vpn_permission_result",
                    mapOf("permission" to "vpn", "granted" to (intent == null)),
                )
                if (intent != null) {
                    runLock.withLock {
                        if (runStateFlow.value == RunState.PENDING) {
                            runTime = 0L
                            runStateFlow.tryEmit(RunState.STOP)
                        }
                    }
                    return false
                }
            }

            // Re-acquire lock: confirm still PENDING, then commit
            return runLock.withLock {
                if (runStateFlow.value != RunState.PENDING) {
                    return@withLock runStateFlow.value == RunState.START
                }
                startServiceLocked()
            }
        } catch (e: Exception) {
            runLock.withLock {
                if (runStateFlow.value == RunState.PENDING) {
                    runTime = 0L
                    runStateFlow.tryEmit(RunState.STOP)
                }
            }
            return false
        }
    }

    private fun startServiceWithPref() {
        GlobalState.launch {
            sharedState = GlobalState.application.sharedState
            setupAndStart()
        }
    }

    suspend fun syncState() {
        Service.updateNotificationParams(
            NotificationParams(
                title = sharedState.currentProfileName,
                stopText = sharedState.stopText,
                onlyStatisticsProxy = sharedState.onlyStatisticsProxy
            )
        )
    }

    private suspend fun setupAndStart() {
        Service.bind()
        syncState()
        GlobalState.application.showToast(sharedState.startTip)
        val initParams = mutableMapOf<String, Any>()
        initParams["home-dir"] = GlobalState.application.filesDir.path
        initParams["version"] = android.os.Build.VERSION.SDK_INT
        val initParamsString = Gson().toJson(initParams)
        val setupParamsString = Gson().toJson(sharedState.setupParams)
        val setupResult = Service.quickSetup(
            initParamsString,
            setupParamsString,
        )
        if (!setupResult.success) {
            GlobalState.log("Setup failed: ${setupResult.errorCode} ${setupResult.message}")
            setupResult.message?.takeIf { it.isNotEmpty() }?.let {
                GlobalState.application.showToast(it)
            }
            runLock.withLock {
                runTime = 0L
                runStateFlow.tryEmit(RunState.STOP)
            }
            return
        }
        startServiceSafely()
    }

    private suspend fun startServiceSafely(): Boolean {
        return runLock.withLock {
            if (runStateFlow.value != RunState.STOP) {
                return@withLock runStateFlow.value == RunState.START
            }
            runStateFlow.tryEmit(RunState.PENDING)
            startServiceLocked()
        }
    }

    private suspend fun startServiceLocked(): Boolean {
        try {
            val options = sharedState.vpnOptions
            if (options == null) {
                runTime = 0L
                runStateFlow.tryEmit(RunState.STOP)
                return false
            }

            val result = Service.startService(options, runTime)
            Phase4Mark.emit(
                "vpn_service_result",
                mapOf(
                    "action" to "start",
                    "success" to result.success,
                    "run_time" to result.runTime,
                    "error_code" to result.errorCode,
                ),
            )
            if (result.success && result.runTime > 0L) {
                val snapshot = awaitStartSnapshot()
                if (snapshot != null) {
                    applySnapshot(snapshot)
                    return snapshot.state == SessionState.RUNNING
                }
                GlobalState.log("Started, but session snapshot remains unavailable")
                runStateFlow.tryEmit(RunState.PENDING)
                return false
            }

            if (result.errorCode == com.follow.clash.service.models.ServiceErrorCode.SERVICE_DISCONNECTED) {
                val snapshot = awaitStartSnapshot()
                if (snapshot != null) {
                    applySnapshot(snapshot)
                    when (snapshot.state) {
                        SessionState.RUNNING -> return true
                        SessionState.STARTING -> return false
                        SessionState.STOPPED -> Unit
                    }
                } else {
                    GlobalState.log("Start result is unknown; keeping pending until snapshot can be reconciled")
                    runStateFlow.tryEmit(RunState.PENDING)
                    return false
                }
            }

            GlobalState.log("Start failed: ${result.errorCode} ${result.message}")
            result.message?.takeIf { it.isNotEmpty() }?.let {
                GlobalState.application.showToast(it)
            }

            runTime = 0L
            runStateFlow.tryEmit(RunState.STOP)
            return false
        } catch (e: Exception) {
            GlobalState.log("Start state reconciliation failed: ${e.message}")
            runStateFlow.tryEmit(RunState.PENDING)
            return false
        }
    }

    private suspend fun awaitStartSnapshot(): SessionSnapshot? {
        repeat(4) { attempt ->
            Service.getSessionSnapshot().getOrNull()?.let { snapshot ->
                if (snapshot.state != SessionState.STARTING || attempt == 3) {
                    return snapshot
                }
            }
            delay(750L)
        }
        return null
    }

    fun handleStopService() {
        GlobalState.launch {
            runLock.withLock {
                if (!canFullStopSession(sessionSnapshot.state)) {
                    return@launch
                }
                try {
                    runStateFlow.tryEmit(RunState.PENDING)
                    val result = Service.stopService()
                    Phase4Mark.emit(
                        "vpn_service_result",
                        mapOf(
                            "action" to "stop",
                            "success" to result.success,
                            "error_code" to result.errorCode,
                        ),
                    )
                    if (result.success) {
                        applySnapshot(
                            Service.getSessionSnapshot().getOrNull()
                                ?: SessionSnapshot.stopped()
                        )
                    } else {
                        GlobalState.log("Stop failed: ${result.errorCode} ${result.message}")
                        Service.getSessionSnapshot().onSuccess(::applySnapshot)
                    }
                } finally {
                    if (runStateFlow.value == RunState.PENDING) {
                        runStateFlow.tryEmit(runStateForSessionState(sessionSnapshot.state))
                    }
                }
            }
        }
    }
}



