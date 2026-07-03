package com.follow.clash

import android.net.VpnService
import com.follow.clash.common.GlobalState
import com.follow.clash.models.SharedState
import com.follow.clash.plugins.AppPlugin
import com.follow.clash.plugins.TilePlugin
import com.follow.clash.service.models.NotificationParams
import com.google.gson.Gson
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

enum class RunState {
    START, PENDING, STOP
}


object State {

    val runLock = Mutex()

    var runTime: Long = 0

    var sharedState: SharedState = SharedState()

    val runStateFlow: MutableStateFlow<RunState> = MutableStateFlow(RunState.STOP)

    var flutterEngine: FlutterEngine? = null

    val appPlugin: AppPlugin?
        get() = flutterEngine?.plugin<AppPlugin>()

    val tilePlugin: TilePlugin?
        get() = flutterEngine?.plugin<TilePlugin>()

    suspend fun handleToggleAction() {
        var action: (suspend () -> Unit)?
        runLock.withLock {
            action = when (runStateFlow.value) {
                RunState.PENDING -> null
                RunState.START -> ::handleStopServiceAction
                RunState.STOP -> ::handleStartServiceAction
            }
        }
        action?.invoke()
    }

    suspend fun handleSyncState() {
        runLock.withLock {
            try {
                Service.bind()
                runTime = Service.getRunTime()
                val runState = when (runTime == 0L) {
                    true -> RunState.STOP
                    false -> RunState.START
                }
                runStateFlow.tryEmit(runState)
            } catch (_: Exception) {
                runTime = 0L
                runStateFlow.tryEmit(RunState.STOP)
            }
        }
    }

    suspend fun handleStartServiceAction() {
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
        if (runStateFlow.value != RunState.START) {
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
                val notificationReady = appPlugin.requestNotificationsPermissionAwait()
                if (!notificationReady) {
                    // 通知权限拒绝不阻断启动，继续
                }
                val vpnPrepared = appPlugin.prepareVpnAwait(options.enable)
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
                val intent = VpnService.prepare(GlobalState.application)
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
        Service.quickSetup(
            initParamsString,
            setupParamsString,
            onStarted = {
                GlobalState.launch {
                    startServiceSafely()
                }
            },
            onResult = {
                if (it.isNotEmpty()) {
                    GlobalState.application.showToast(it)
                }
            },
        )
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

            val nextRunTime = Service.startService(options, runTime)
            if (nextRunTime > 0L) {
                runTime = nextRunTime
                runStateFlow.tryEmit(RunState.START)
                return true
            }

            runTime = 0L
            runStateFlow.tryEmit(RunState.STOP)
            return false
        } catch (e: Exception) {
            runTime = 0L
            runStateFlow.tryEmit(RunState.STOP)
            return false
        } finally {
            if (runStateFlow.value == RunState.PENDING) {
                runStateFlow.tryEmit(RunState.STOP)
            }
        }
    }

    fun handleStopService() {
        GlobalState.launch {
            runLock.withLock {
                if (runStateFlow.value != RunState.START) {
                    return@launch
                }
                try {
                    runStateFlow.tryEmit(RunState.PENDING)
                    runTime = Service.stopService()
                    runStateFlow.tryEmit(RunState.STOP)
                } finally {
                    if (runStateFlow.value == RunState.PENDING) {
                        runStateFlow.tryEmit(RunState.START)
                    }
                }
            }
        }
    }
}



