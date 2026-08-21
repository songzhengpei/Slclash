package com.follow.clash.service

import android.app.Service
import android.content.Intent
import android.os.IBinder
import com.follow.clash.common.GlobalState
import com.follow.clash.common.Phase4Mark
import com.follow.clash.common.ServiceDelegate
import com.follow.clash.common.chunkedForAidl
import com.follow.clash.common.intent
import com.follow.clash.core.Core
import com.follow.clash.service.State.delegate
import com.follow.clash.service.State.intent
import com.follow.clash.service.State.runLock
import com.follow.clash.service.models.NotificationParams
import com.follow.clash.service.models.SessionSnapshot
import com.follow.clash.service.models.SessionState
import com.follow.clash.service.models.SessionTransitions
import com.follow.clash.service.models.ServiceErrorCode
import com.follow.clash.service.models.ServiceOperationResult
import com.follow.clash.service.models.VpnOptions
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withTimeoutOrNull
import java.util.UUID
import java.util.concurrent.atomic.AtomicLong
import kotlin.coroutines.resume

internal fun canReuseRunningSession(state: String, operational: Boolean): Boolean =
    state == SessionState.RUNNING && operational

class RemoteService : Service(), CoroutineScope {
    private val serviceJob = SupervisorJob()
    override val coroutineContext = serviceJob + Dispatchers.Default
    private val sessionCounter = AtomicLong(System.currentTimeMillis())
    private var delegateGeneration = 0L

    private fun clearDelegate() {
        delegate?.unbind()
        delegate = null
        intent = null
        delegateGeneration += 1L
    }

    private fun applySession(snapshot: SessionSnapshot) {
        State.snapshot = snapshot
        if (SessionState.keepsRemoteService(snapshot.state)) {
            runCatching { startService(Intent(this, RemoteService::class.java)) }
        } else {
            stopSelf()
        }
    }
    private fun replyOperation(
        callback: IOperationResultInterface,
        result: ServiceOperationResult,
    ) {
        runCatching { callback.onResult(result) }
            .onFailure { GlobalState.log("Operation result callback failed: ${it.message}") }
    }

    private fun handleStopService(result: IOperationResultInterface) {
        Phase4Mark.emit(
            "vpn_service_dispatch",
            mapOf("action" to "stop", "state" to State.snapshot.state),
        )
        launch {
            runLock.withLock {
                val current = State.snapshot
                if (current.state == SessionState.STOPPED) {
                    replyOperation(result, ServiceOperationResult.success())
                    return@withLock
                }
                applySession(SessionTransitions.stopping(current))
                val stopResult = delegate?.useService(timeoutMillis = 10_000L) { service ->
                    service.stop()
                }?.getOrNull() ?: ServiceOperationResult.failure(
                    ServiceErrorCode.SERVICE_DISCONNECTED,
                    "Background service is unavailable during stop",
                )
                clearDelegate()
                applySession(
                    if (stopResult.success) {
                    SessionSnapshot.stopped()
                } else {
                    State.snapshot.copy(
                        state = SessionState.STOPPING,
                        lastErrorCode = stopResult.errorCode,
                        lastErrorMessage = stopResult.message,
                    )
                }
                )
                replyOperation(result, stopResult)
            }
        }
    }

    private fun handleServiceDisconnected(generation: Long, message: String) {
        Phase4Mark.emit(
            "vpn_remote_disconnected",
            mapOf("service" to "background", "state" to State.snapshot.state, "message" to message),
        )
        GlobalState.log("Background service disconnected: $message")
        launch {
            runLock.withLock {
                // A disconnect from a service discarded during handover must
                // not overwrite the replacement session that is now RUNNING.
                if (generation != delegateGeneration) return@withLock
                clearDelegate()
                applySession(
                    if (
                    State.snapshot.state == SessionState.STOPPING ||
                    State.snapshot.state == SessionState.STOPPED
                ) {
                    State.snapshot.copy(
                        lastErrorCode = ServiceErrorCode.SERVICE_DISCONNECTED,
                        lastErrorMessage = message,
                    )
                } else {
                    State.snapshot.copy(
                        state = SessionState.STOPPING,
                        lastErrorCode = ServiceErrorCode.SERVICE_DISCONNECTED,
                        lastErrorMessage = message,
                    )
                }
                )
            }
        }
    }

    private fun handleStartService(
        options: VpnOptions,
        runTime: Long,
        result: IOperationResultInterface,
    ) {
        Phase4Mark.emit(
            "vpn_service_dispatch",
            mapOf("action" to "start", "state" to State.snapshot.state, "run_time" to runTime),
        )
        launch {
            runLock.withLock {
                var current = State.snapshot
                if (current.state == SessionState.RUNNING) {
                    val operational = delegate?.useService { service ->
                        service.isOperational()
                    }?.getOrNull() == true
                    if (canReuseRunningSession(current.state, operational)) {
                        applySession(current)
                        replyOperation(result, ServiceOperationResult.success(current.startedAt))
                        return@withLock
                    }

                    // A different VPN app can revoke our TUN while the remote
                    // process and its RUNNING snapshot remain alive. Discard
                    // that stale session so this explicit Start establishes a
                    // new interface and reclaims Android VPN ownership.
                    GlobalState.log("Discard stale RUNNING session without an operational service")
                    delegate?.useService(timeoutMillis = 10_000L) { service ->
                        service.stop()
                    }
                    clearDelegate()
                    applySession(SessionSnapshot.stopped())
                    current = State.snapshot
                }
                if (current.state == SessionState.PAUSED) {
                    val resumed = delegate?.useService { it.smartResume() }?.getOrNull() == true
                    if (resumed) {
                        applySession(SessionTransitions.running(current))
                        replyOperation(result, ServiceOperationResult.success(current.startedAt))
                    } else {
                        replyOperation(
                            result,
                            ServiceOperationResult.failure(
                                ServiceErrorCode.TUN_START_FAILED,
                                "Paused session failed to resume",
                            ),
                        )
                    }
                    return@withLock
                }
                if (current.state != SessionState.STOPPED) {
                    replyOperation(
                        result,
                        ServiceOperationResult.failure(
                            ServiceErrorCode.INTERNAL_ERROR,
                            "Session is busy: ${current.state}",
                        ),
                    )
                    return@withLock
                }
                val sessionId = sessionCounter.incrementAndGet()
                val startedAt = runTime.takeIf { it > 0L } ?: System.currentTimeMillis()
                State.options = options
                applySession(SessionTransitions.starting(sessionId, startedAt))
                try {
                    val nextIntent = when (options.enable) {
                        true -> VpnService::class.intent
                        false -> CommonService::class.intent
                    }
                    if (intent != nextIntent) {
                        clearDelegate()
                        val generation = delegateGeneration
                        delegate = ServiceDelegate(
                            nextIntent,
                            { message -> handleServiceDisconnected(generation, message) },
                        ) { binder ->
                            when (binder) {
                                is VpnService.LocalBinder -> binder.getService()
                                is CommonService.LocalBinder -> binder.getService()
                                else -> throw IllegalArgumentException("Invalid binder type")
                            }
                        }
                        intent = nextIntent
                        delegate?.bind()
                    }

                    var startResult: ServiceOperationResult? = null
                    delegate?.useService { service ->
                        startResult = service.start()
                    }

                    val serviceResult = startResult ?: ServiceOperationResult.failure(
                        ServiceErrorCode.SERVICE_DISCONNECTED,
                        "Background service is unavailable",
                    )
                    if (!serviceResult.success) {
                        GlobalState.log("Start service failed: ${serviceResult.errorCode} ${serviceResult.message}")
                        rollbackStart(serviceResult.errorCode, serviceResult.message)
                        replyOperation(result, serviceResult)
                        return@withLock
                    }

                    applySession(SessionTransitions.running(State.snapshot))
                    replyOperation(result, ServiceOperationResult.success(startedAt))
                } catch (e: Exception) {
                    GlobalState.log("Start service internal error: ${e.message}")
                    rollbackStart(ServiceErrorCode.INTERNAL_ERROR, e.message)
                    replyOperation(
                        result,
                        ServiceOperationResult.failure(
                            ServiceErrorCode.INTERNAL_ERROR,
                            e.message,
                        ),
                    )
                }
            }
        }
    }

    private suspend fun rollbackStart(errorCode: String?, message: String?) {
        val activeDelegate = delegate
        val cleanupSucceeded = if (activeDelegate == null) {
            true
        } else {
            activeDelegate.useService(timeoutMillis = 10_000L) { service ->
                service.stop()
            }.getOrNull()?.success == true
        }
        clearDelegate()
        applySession(
            if (cleanupSucceeded) {
            SessionSnapshot.stopped(errorCode, message)
        } else {
            State.snapshot.copy(
                state = SessionState.STOPPING,
                lastErrorCode = errorCode,
                lastErrorMessage = message,
            )
        }
        )
    }

    private val binder = object : IRemoteInterface.Stub() {
        override fun invokeAction(data: String, callback: ICallbackInterface) {
            Core.invokeAction(data) {
                launch {
                    runCatching {
                        val chunks = it?.chunkedForAidl() ?: listOf()
                        for ((index, chunk) in chunks.withIndex()) {
                            suspendCancellableCoroutine { cont ->
                                callback.onResult(
                                    chunk,
                                    index == chunks.lastIndex,
                                    object : IAckInterface.Stub() {
                                        override fun onAck() {
                                            cont.resume(Unit)
                                        }
                                    },
                                )
                            }
                        }
                    }
                }
            }
        }

        override fun quickSetup(
            initParamsString: String,
            setupParamsString: String,
            result: IOperationResultInterface,
        ) {
            Core.quickSetup(initParamsString, setupParamsString) {
                launch {
                    runLock.withLock {
                        val message = it.orEmpty()
                        val operationResult = when {
                            message.isEmpty() -> ServiceOperationResult.success()
                            message == "init failed" -> ServiceOperationResult.failure(
                                ServiceErrorCode.CORE_INIT_FAILED,
                                message,
                            )
                            else -> ServiceOperationResult.failure(
                                ServiceErrorCode.CONFIG_LOAD_FAILED,
                                message,
                            )
                        }
                        if (!operationResult.success) {
                            applySession(
                                SessionSnapshot.stopped(
                                operationResult.errorCode,
                                operationResult.message,
                            )
                            )
                        }
                        replyOperation(result, operationResult)
                    }
                }
            }
        }

        override fun updateNotificationParams(params: NotificationParams?) {
            State.notificationParamsFlow.tryEmit(params)
        }


        override fun startService(
            options: VpnOptions,
            runtime: Long,
            result: IOperationResultInterface,
        ) {
            GlobalState.log("remote startService")
            handleStartService(options, runtime, result)
        }

        override fun stopService(result: IOperationResultInterface) {
            handleStopService(result)
        }

        override fun setEventListener(eventListener: IEventInterface?) {
            GlobalState.log("RemoveEventListener ${eventListener == null}")
            when (eventListener != null) {
                true -> Core.callSetEventListener {
                    launch {
                        runCatching {
                            val id = UUID.randomUUID().toString()
                            val chunks = it?.chunkedForAidl() ?: listOf()
                            for ((index, chunk) in chunks.withIndex()) {
                                suspendCancellableCoroutine { cont ->
                                    eventListener.onEvent(
                                        id,
                                        chunk,
                                        index == chunks.lastIndex,
                                        object : IAckInterface.Stub() {
                                            override fun onAck() {
                                                cont.resume(Unit)
                                            }
                                        },
                                    )
                                }
                            }
                        }
                    }
                }

                false -> Core.callSetEventListener(null)
            }
        }

        override fun getRunTime(): Long {
            return State.snapshot.takeIf { it.state == SessionState.RUNNING }?.startedAt ?: 0L
        }

        override fun getSessionSnapshot(): SessionSnapshot {
            Phase4Mark.emit(
                "vpn_snapshot",
                mapOf(
                    "layer" to "remote_binder",
                    "state" to State.snapshot.state,
                    "session_id" to State.snapshot.sessionId,
                    "smart_paused" to State.snapshot.smartPaused,
                ),
            )
            return State.snapshot
        }

        override fun smartStop(result: IResultInterface) {
            Phase4Mark.emit(
                "smart_stop_begin",
                mapOf("state" to State.snapshot.state, "session_id" to State.snapshot.sessionId),
            )
            launch {
                runLock.withLock {
                    // Already stopped — return success (idempotent)
                    val current = State.snapshot
                    if (current.state == SessionState.PAUSED) {
                        Phase4Mark.emit(
                            "smart_stop_complete",
                            mapOf("result_class" to "idempotent", "state" to current.state),
                        )
                        result.onResult(1)
                        return@withLock
                    }
                    if (current.state != SessionState.RUNNING) {
                        Phase4Mark.emit(
                            "smart_stop_complete",
                            mapOf("result_class" to "rejected", "state" to current.state),
                        )
                        result.onResult(0)
                        return@withLock
                    }
                    val d = delegate
                    if (d == null) {
                        result.onResult(0)
                        return@withLock
                    }
                    var success = false
                    d.useService { service ->
                        service.smartStop()
                        success = true
                    }
                    if (success) {
                        applySession(SessionTransitions.paused(current))
                        Phase4Mark.emit(
                            "smart_stop_complete",
                            mapOf("result_class" to "success", "state" to State.snapshot.state),
                        )
                        result.onResult(1)
                    } else {
                        Phase4Mark.emit(
                            "smart_stop_complete",
                            mapOf("result_class" to "service_unavailable", "state" to current.state),
                        )
                        result.onResult(0)
                    }
                }
            }
        }

        override fun smartResume(result: IResultInterface) {
            Phase4Mark.emit(
                "smart_resume_begin",
                mapOf("state" to State.snapshot.state, "session_id" to State.snapshot.sessionId),
            )
            launch {
                runLock.withLock {
                    // Not stopped — return current runTime (idempotent)
                    val current = State.snapshot
                    if (current.state != SessionState.PAUSED) {
                        Phase4Mark.emit(
                            "smart_resume_complete",
                            mapOf("result_class" to "idempotent_or_rejected", "state" to current.state),
                        )
                        result.onResult(
                            current.takeIf { it.state == SessionState.RUNNING }?.startedAt ?: 0L
                        )
                        return@withLock
                    }
                    val options = State.options
                    val d = delegate
                    if (options == null || d == null) {
                        result.onResult(0)
                        return@withLock
                    }
                    var success = false
                    d.useService { service ->
                        success = service.smartResume()
                    }
                    if (success) {
                        applySession(SessionTransitions.running(current))
                        Phase4Mark.emit(
                            "smart_resume_complete",
                            mapOf("result_class" to "success", "state" to State.snapshot.state),
                        )
                        result.onResult(current.startedAt)
                    } else {
                        Phase4Mark.emit(
                            "smart_resume_complete",
                            mapOf("result_class" to "tun_start_failed", "state" to current.state),
                        )
                        result.onResult(0)
                    }
                }
            }
        }

        override fun setSmartStopped(value: Boolean) {
            if (State.snapshot.smartPaused != value) {
                GlobalState.log("Ignoring stale smart-pause flag; physical service state is authoritative")
            }
        }

        override fun isSmartStopped(): Boolean {
            return State.snapshot.smartPaused
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder {
        return binder
    }

    override fun onDestroy() {
        if (SessionState.keepsRemoteService(State.snapshot.state)) {
            GlobalState.log(
                "RemoteService onDestroy with active session ${State.snapshot.state}; keeping VPN"
            )
            serviceJob.cancel()
            super.onDestroy()
            return
        }
        runBlocking {
            withTimeoutOrNull(2_000L) {
                runLock.withLock {
                    val activeDelegate = delegate
                    val stopped = if (activeDelegate == null) {
                        true
                    } else {
                        activeDelegate.useService(timeoutMillis = 1_500L) { service ->
                            service.stop()
                        }.getOrNull()?.success == true
                    }
                    clearDelegate()
                    applySession(
                        if (stopped) {
                            SessionSnapshot.stopped()
                        } else {
                            State.snapshot.copy(
                                state = SessionState.STOPPING,
                                lastErrorCode = ServiceErrorCode.SERVICE_DISCONNECTED,
                                lastErrorMessage = "Remote service destroyed before cleanup completed",
                            )
                        }
                    )
                }
            }
        }
        Core.callSetEventListener(null)
        serviceJob.cancel()
        GlobalState.log("Remote service destroy")
        super.onDestroy()
    }
}
