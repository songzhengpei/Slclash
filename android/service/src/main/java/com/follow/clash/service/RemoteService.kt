package com.follow.clash.service

import android.app.Service
import android.content.Context
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
import com.follow.clash.service.modules.PhysicalNetworkControlPlane
import com.follow.clash.service.modules.PhysicalNetworkSnapshot
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withTimeoutOrNull
import java.util.UUID
import java.util.concurrent.atomic.AtomicLong
import kotlin.coroutines.resume

internal fun quickSetupOperationResult(message: String?): ServiceOperationResult = when {
    message == null -> ServiceOperationResult.failure(
        ServiceErrorCode.INTERNAL_ERROR,
        "Core quick setup returned no result",
    )
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

internal fun canReuseRunningSession(state: String, operational: Boolean): Boolean =
    state == SessionState.RUNNING && operational

internal fun disconnectedSessionSnapshot(message: String): SessionSnapshot =
    SessionSnapshot.stopped(ServiceErrorCode.SERVICE_DISCONNECTED, message)

internal data class CleanupResolution(
    val snapshot: SessionSnapshot,
    val clearDelegate: Boolean,
)

internal fun cleanupResolution(
    current: SessionSnapshot,
    result: ServiceOperationResult,
): CleanupResolution = if (result.success) {
    CleanupResolution(
        snapshot = SessionSnapshot.stopped(),
        clearDelegate = true,
    )
} else {
    CleanupResolution(
        snapshot = current.copy(
            state = SessionState.STOPPING,
            lastErrorCode = result.errorCode,
            lastErrorMessage = result.message,
        ),
        clearDelegate = false,
    )
}

internal fun isCurrentDelegateGeneration(callbackGeneration: Long, currentGeneration: Long): Boolean =
    callbackGeneration == currentGeneration

class RemoteService : Service(), CoroutineScope {
    private val serviceJob = SupervisorJob()
    override val coroutineContext = serviceJob + Dispatchers.Default
    private val sessionCounter = AtomicLong(System.currentTimeMillis())
    private var delegateGeneration = 0L
    private val smartPausePolicy = SmartPausePolicy()
    @Volatile private var smartPauseConfig = SmartPauseConfig()
    @Volatile private var latestPhysicalNetwork: PhysicalNetworkSnapshot? = null
    private lateinit var policyExecutor: ConflatedPolicyExecutor<String>
    private val retryEpoch = AtomicLong(0L)
    private val unknownRetrySchedule = BoundedRetrySchedule(RETRY_DELAYS)
    private val transitionRetrySchedule = BoundedRetrySchedule(RETRY_DELAYS)
    private var unknownRetryJob: Job? = null
    private var transitionRetryJob: Job? = null
    private var lastStableNetworkId: Long? = null

    override fun onCreate() {
        super.onCreate()
        val preferences = getSharedPreferences(SMART_PAUSE_PREFERENCES, Context.MODE_PRIVATE)
        smartPauseConfig = SmartPauseConfig(
            enabled = preferences.getBoolean(KEY_ENABLED, false),
            trustedNetworks = preferences.getStringSet(KEY_NETWORKS, emptySet()).orEmpty().toList(),
            closeConnections = preferences.getBoolean(KEY_CLOSE_CONNECTIONS, true),
        )
        policyExecutor = ConflatedPolicyExecutor(
            scope = this,
            evaluate = ::evaluateSmartPause,
            onError = { GlobalState.log("Smart Pause policy evaluator failed: ${it.message}") },
        )
        PhysicalNetworkControlPlane.attach(::onPhysicalNetworkSnapshot)
    }

    private fun onPhysicalNetworkSnapshot(snapshot: PhysicalNetworkSnapshot) {
        latestPhysicalNetwork = snapshot
        invalidateTransitionRetry()
        if (snapshot.isKnown) {
            unknownRetryJob?.cancel()
            unknownRetryJob = null
            unknownRetrySchedule.reset()
        }
        Phase4Mark.emit(
            "smart_pause_network_snapshot",
            mapOf(
                "network_generation" to snapshot.generation,
                "network_type" to snapshot.transport,
                "ip_count" to snapshot.ipv4Addresses.size,
                "known" to snapshot.isKnown,
            ),
        )
        requestSmartPauseEvaluation("network")
    }

    private fun requestSmartPauseEvaluation(reason: String): Long = policyExecutor.submit(reason)

    private suspend fun evaluateSmartPause(reason: String) {
        runLock.withLock {
            // Read the latest physical truth only after acquiring the lifecycle
            // lock. A snapshot captured while waiting for runLock is stale.
            val network = latestPhysicalNetwork
            val current = State.snapshot
            val config = smartPauseConfig
            if (config.enabled && config.trustedNetworks.isNotEmpty() &&
                (network == null || !network.isKnown)
            ) scheduleUnknownRetry()
            val trusted = network?.let {
                it.isKnown && TrustedNetworkMatcher.matchesAny(it.ipv4Addresses, config.trustedNetworks)
            } == true
            val previousOverride = smartPausePolicy.manualOverride
            val policyConfig = config.copy(
                enabled = config.enabled && State.options?.enable == true,
            )
            val decision = smartPausePolicy.evaluate(
                policyConfig, current.state, network?.isKnown == true, trusted,
            )
            if (previousOverride != smartPausePolicy.manualOverride) {
                Phase4Mark.emit(
                    "smart_pause_override_changed",
                    mapOf(
                        "manual_override" to smartPausePolicy.manualOverride,
                        "source" to "policy",
                    ),
                )
            }
            Phase4Mark.emit(
                "smart_pause_evaluate",
                mapOf(
                    "session_state" to current.state,
                    "session_id" to current.sessionId,
                    "smart_paused" to current.smartPaused,
                    "state_options_enable" to State.options?.enable,
                    "config_enabled" to config.enabled,
                    "network_known" to (network?.isKnown == true),
                    "network_generation" to (network?.generation ?: 0L),
                    "trusted" to trusted,
                    "ip_count" to (network?.ipv4Addresses?.size ?: 0),
                    "reason" to reason,
                    "manual_override" to smartPausePolicy.manualOverride,
                    "decision" to decision.name,
                    "attempt" to (transitionRetrySchedule.executedAttempts + 1),
                ),
            )
            maybeCloseConnectionsForHandover(network, config, current)
            val transitionSucceeded = when (decision) {
                SmartPauseDecision.PAUSE -> transitionSmartPauseLocked(current, true, "native_policy")
                SmartPauseDecision.RESUME -> resumePausedSessionLocked(
                    current,
                    PausedResumeSource.POLICY,
                )
                SmartPauseDecision.NONE -> null
            }
            when (transitionSucceeded) {
                true -> clearTransitionRetry()
                false -> scheduleTransitionRetry()
                null -> Unit
            }
        }
    }

    @Synchronized
    private fun scheduleUnknownRetry() {
        if (unknownRetryJob?.isActive == true) return
        val retryDelay = unknownRetrySchedule.nextDelay() ?: return
        val attempt = unknownRetrySchedule.executedAttempts + 1
        Phase4Mark.emit("smart_pause_retry", mapOf("kind" to "unknown", "attempt" to attempt, "delay_ms" to retryDelay))
        unknownRetryJob = launch {
            delay(retryDelay)
            synchronized(this@RemoteService) {
                unknownRetryJob = null
                unknownRetrySchedule.markExecuted()
            }
            PhysicalNetworkControlPlane.refresh()
        }
    }

    @Synchronized
    private fun scheduleTransitionRetry() {
        if (transitionRetryJob?.isActive == true) return
        val retryDelay = transitionRetrySchedule.nextDelay() ?: return
        val attempt = transitionRetrySchedule.executedAttempts + 1
        val epoch = retryEpoch.get()
        Phase4Mark.emit("smart_pause_retry", mapOf("kind" to "transition", "attempt" to attempt, "delay_ms" to retryDelay))
        transitionRetryJob = launch {
            delay(retryDelay)
            synchronized(this@RemoteService) {
                transitionRetryJob = null
                if (retryEpoch.get() != epoch) return@launch
                transitionRetrySchedule.markExecuted()
            }
            requestSmartPauseEvaluation("transition_retry")
        }
    }

    @Synchronized
    private fun invalidateTransitionRetry() {
        retryEpoch.incrementAndGet()
        clearTransitionRetry()
    }

    @Synchronized
    private fun clearTransitionRetry() {
        transitionRetryJob?.cancel()
        transitionRetryJob = null
        transitionRetrySchedule.reset()
    }

    @Synchronized
    private fun resetAllPolicyRetries() {
        retryEpoch.incrementAndGet()
        clearTransitionRetry()
        unknownRetryJob?.cancel()
        unknownRetryJob = null
        unknownRetrySchedule.reset()
    }

    private fun maybeCloseConnectionsForHandover(
        network: PhysicalNetworkSnapshot?, config: SmartPauseConfig, session: SessionSnapshot,
    ) {
        val networkId = network?.takeIf { it.isKnown }?.networkId ?: return
        val previous = lastStableNetworkId
        lastStableNetworkId = networkId
        if (previous == null || previous == networkId || !config.closeConnections ||
            (session.state != SessionState.RUNNING && session.state != SessionState.PAUSED)
        ) return
        Phase4Mark.emit(
            "network_handover_close_connections",
            mapOf("network_generation" to network.generation, "network_type" to network.transport),
        )
        val action = "{\"id\":\"native-network-${network.generation}\",\"method\":\"closeConnections\",\"data\":null}"
        Core.invokeAction(action) { result ->
            Phase4Mark.emit(
                "network_handover_close_connections_complete",
                mapOf("result" to (result != null)),
            )
        }
    }

    private suspend fun transitionSmartPauseLocked(
        current: SessionSnapshot, pause: Boolean, source: String,
    ): Boolean {
        Phase4Mark.emit(
            "smart_pause_transition_requested",
            mapOf("session_state" to current.state, "action" to if (pause) "pause" else "resume", "source" to source),
        )
        val active = delegate
        if (active == null) {
            if (!pause) {
                Phase4Mark.emit(
                    "smart_pause_resume",
                    mapOf(
                        "phase" to "vpn_service_result",
                        "result" to false,
                        "tun_operational" to false,
                        "failure" to "delegate_absent",
                    ),
                )
            }
            Phase4Mark.emit(
                "smart_pause_transition_complete",
                mapOf("result" to false, "session_state" to State.snapshot.state, "source" to source),
            )
            return false
        }
        val serviceResult = active.useService { service ->
            if (pause) {
                service.smartStop() && !service.isOperational()
            } else {
                Phase4Mark.emit("smart_pause_resume", mapOf("phase" to "vpn_service_begin"))
                val resumed = service.smartResume()
                val operational = resumed && service.isOperational()
                Phase4Mark.emit(
                    "smart_pause_resume",
                    mapOf(
                        "phase" to "vpn_service_result",
                        "result" to resumed,
                        "tun_operational" to operational,
                    ),
                )
                operational
            }
        }
        if (!pause && serviceResult.isFailure) {
            Phase4Mark.emit(
                "smart_pause_resume",
                mapOf(
                    "phase" to "vpn_service_result",
                    "result" to false,
                    "tun_operational" to false,
                    "failure" to "service_call_failed",
                ),
            )
        }
        val success = serviceResult.getOrNull() == true
        if (success) applySession(
            if (pause) SessionTransitions.paused(current) else SessionTransitions.running(current),
        )
        Phase4Mark.emit(
            "smart_pause_transition_complete",
            mapOf("result" to success, "session_state" to State.snapshot.state, "source" to source),
        )
        return success
    }

    private suspend fun resumePausedSessionLocked(
        current: SessionSnapshot,
        source: PausedResumeSource,
    ): Boolean {
        Phase4Mark.emit(
            "smart_pause_resume",
            mapOf(
                "phase" to "begin",
                "source" to source.name.lowercase(),
                "session_state" to current.state,
                "session_id" to current.sessionId,
                "attempt" to (transitionRetrySchedule.executedAttempts + 1),
            ),
        )
        val success = transitionSmartPauseLocked(
            current = current,
            pause = false,
            source = source.name.lowercase(),
        )
        if (!success) {
            Phase4Mark.emit(
                "smart_pause_resume",
                mapOf(
                    "phase" to "final",
                    "result" to false,
                    "final_state" to State.snapshot.state,
                    "session_id" to State.snapshot.sessionId,
                ),
            )
            return false
        }
        smartPausePolicy.markManualResume(
            manualResumeTrusted(source, latestPhysicalNetwork, smartPauseConfig),
        )
        Phase4Mark.emit(
            "smart_pause_override_changed",
            mapOf(
                "manual_override" to smartPausePolicy.manualOverride,
                "source" to source.name.lowercase(),
            ),
        )
        Phase4Mark.emit(
            "smart_pause_resume",
            mapOf(
                "phase" to "final",
                "result" to true,
                "tun_operational" to true,
                "final_state" to State.snapshot.state,
                "session_id" to State.snapshot.sessionId,
                "smart_paused" to State.snapshot.smartPaused,
            ),
        )
        return true
    }

    private fun clearDelegate() {
        delegate?.unbind()
        delegate = null
        intent = null
        delegateGeneration += 1L
    }

    private fun applySession(snapshot: SessionSnapshot) {
        if (snapshot.state == SessionState.STOPPED && smartPausePolicy.manualOverride) {
            smartPausePolicy.onSessionStopped()
            Phase4Mark.emit(
                "smart_pause_override_changed",
                mapOf(
                    "manual_override" to false,
                    "source" to "session_stopped",
                ),
            )
        }
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
        resetAllPolicyRetries()
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
                val resolution = cleanupResolution(State.snapshot, stopResult)
                if (resolution.clearDelegate) clearDelegate()
                applySession(resolution.snapshot)
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
                if (!isCurrentDelegateGeneration(generation, delegateGeneration)) return@withLock
                clearDelegate()
                // The bound physical service is gone and this delegate does
                // not reconnect automatically. STOPPING would therefore be a
                // permanent phantom state with no actor left to complete it.
                applySession(disconnectedSessionSnapshot(message))
            }
        }
    }

    private fun handleStartService(
        options: VpnOptions,
        runTime: Long,
        result: IOperationResultInterface,
    ) {
        resetAllPolicyRetries()
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
                    val resumed = resumePausedSessionLocked(current, PausedResumeSource.USER)
                    if (resumed) {
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
                    requestSmartPauseEvaluation("session_started")
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
        val cleanupResult = if (activeDelegate == null) {
            ServiceOperationResult.success()
        } else {
            activeDelegate.useService(timeoutMillis = 10_000L) { service ->
                service.stop()
            }.getOrElse {
                ServiceOperationResult.failure(ServiceErrorCode.SERVICE_DISCONNECTED, it.message)
            }
        }
        val resolution = cleanupResolution(
            current = State.snapshot,
            result = if (cleanupResult.success) {
                ServiceOperationResult.success()
            } else {
                ServiceOperationResult.failure(
                    errorCode ?: cleanupResult.errorCode ?: ServiceErrorCode.INTERNAL_ERROR,
                    message ?: cleanupResult.message,
                )
            },
        )
        if (resolution.clearDelegate) clearDelegate()
        applySession(
            if (resolution.clearDelegate && (errorCode != null || message != null)) {
                SessionSnapshot.stopped(errorCode, message)
            } else {
                resolution.snapshot
            },
        )
    }

    private val binder = object : IRemoteInterface.Stub() {
        override fun invokeAction(data: String, callback: ICallbackInterface) {
            Core.invokeAction(data) {
                launch {
                    runCatching {
                        val chunks = it?.chunkedForAidl().orEmpty()
                        if (chunks.isEmpty()) {
                            callback.onResult(null, true, null)
                            return@runCatching
                        }
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
                        val operationResult = quickSetupOperationResult(it)
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
            resetAllPolicyRetries()
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
                    val success = transitionSmartPauseLocked(current, true, "manual")
                    if (success) {
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
            resetAllPolicyRetries()
            Phase4Mark.emit(
                "smart_resume_begin",
                mapOf("state" to State.snapshot.state, "session_id" to State.snapshot.sessionId),
            )
            launch {
                runLock.withLock {
                    // Only a physically operational RUNNING session is
                    // idempotent. A stale snapshot must not confirm resume.
                    val current = State.snapshot
                    if (current.state != SessionState.PAUSED) {
                        val operational = if (current.state == SessionState.RUNNING) {
                            delegate?.useService { it.isOperational() }?.getOrNull() == true
                        } else {
                            false
                        }
                        if (current.state == SessionState.RUNNING && !operational) {
                            delegate?.useService(timeoutMillis = 10_000L) { it.stop() }
                            clearDelegate()
                            applySession(
                                SessionSnapshot.stopped(
                                    ServiceErrorCode.SERVICE_DISCONNECTED,
                                    "RUNNING session is not operational",
                                )
                            )
                        }
                        Phase4Mark.emit(
                            "smart_resume_complete",
                            mapOf(
                                "result_class" to if (operational) "idempotent" else "rejected",
                                "state" to State.snapshot.state,
                            ),
                        )
                        result.onResult(current.takeIf { operational }?.startedAt ?: 0L)
                        return@withLock
                    }
                    val options = State.options
                    if (options == null || delegate == null) {
                        result.onResult(0)
                        return@withLock
                    }
                    val success = resumePausedSessionLocked(current, PausedResumeSource.USER)
                    if (success) {
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

        override fun updateSmartPauseConfig(
            enabled: Boolean,
            trustedNetworks: MutableList<String>?,
            closeConnections: Boolean,
        ) {
            resetAllPolicyRetries()
            val networks = trustedNetworks.orEmpty().map(String::trim).filter(String::isNotEmpty)
            smartPauseConfig = SmartPauseConfig(enabled, networks, closeConnections)
            getSharedPreferences(SMART_PAUSE_PREFERENCES, Context.MODE_PRIVATE).edit()
                .putBoolean(KEY_ENABLED, enabled)
                .putStringSet(KEY_NETWORKS, networks.toSet())
                .putBoolean(KEY_CLOSE_CONNECTIONS, closeConnections)
                .apply()
            requestSmartPauseEvaluation("config_change")
        }

        override fun reevaluateSmartPause(result: IResultInterface) {
            launch {
                PhysicalNetworkControlPlane.refresh()
                val generation = requestSmartPauseEvaluation("foreground_reevaluate")
                policyExecutor.await(generation)
                result.onResult(1L)
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder {
        return binder
    }

    override fun onDestroy() {
        PhysicalNetworkControlPlane.detach()
        resetAllPolicyRetries()
        policyExecutor.close()
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

    companion object {
        private const val SMART_PAUSE_PREFERENCES = "smart_pause_control"
        private const val KEY_ENABLED = "enabled"
        private const val KEY_NETWORKS = "trusted_networks"
        private const val KEY_CLOSE_CONNECTIONS = "close_connections"
        private val RETRY_DELAYS = longArrayOf(500L, 1_500L, 3_000L)
    }
}
