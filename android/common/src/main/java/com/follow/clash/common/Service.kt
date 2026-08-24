package com.follow.clash.common

import android.content.Intent
import android.os.IBinder
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.takeWhile
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout

internal class BindAttemptOwnership {
    private var nextGeneration = 0L
    private var currentGeneration = 0L

    @Synchronized
    fun begin(): Long? {
        if (currentGeneration != 0L) return null
        nextGeneration += 1L
        currentGeneration = nextGeneration
        return currentGeneration
    }

    @Synchronized
    fun isCurrent(generation: Long): Boolean =
        currentGeneration == generation

    @Synchronized
    fun release(generation: Long): Boolean {
        if (currentGeneration != generation) return false
        currentGeneration = 0L
        return true
    }

    @Synchronized
    fun invalidate(): Boolean {
        if (currentGeneration == 0L) return false
        currentGeneration = 0L
        return true
    }
}

internal fun unexpectedBindTerminalMessage(
    ownership: BindAttemptOwnership,
    attempt: Long,
    terminalResult: Result<Unit>,
): String? {
    if (!ownership.release(attempt)) return null
    return terminalResult.exceptionOrNull()?.message
        ?: "Service binding ended unexpectedly"
}

class ServiceDelegate<T>(
    private val intent: Intent,
    private val onServiceDisconnected: ((String) -> Unit)? = null,
    private val interfaceCreator: (IBinder) -> T,
) : CoroutineScope by CoroutineScope(SupervisorJob() + Dispatchers.Default) {

    private val bindAttempts = BindAttemptOwnership()

    private var _serviceState = MutableStateFlow<Pair<T?, String>?>(null)

    val serviceState: StateFlow<Pair<T?, String>?> = _serviceState
    private var job: Job? = null

    private fun handleBind(attempt: Long, data: Pair<IBinder?, String>): Boolean {
        if (!bindAttempts.isCurrent(attempt)) return false
        data.first?.let {
            _serviceState.value = Pair(interfaceCreator(it), data.second)
            Phase4Mark.emit(
                "vpn_remote_connected",
                mapOf("service" to intent.component?.className),
            )
            return true
        } ?: run {
            Phase4Mark.emit(
                "vpn_remote_disconnected",
                mapOf("service" to intent.component?.className, "message" to data.second),
            )
            if (bindAttempts.release(attempt)) {
                _serviceState.value = Pair(null, data.second)
                onServiceDisconnected?.invoke(data.second)
            }
            return false
        }
    }

    fun bind() {
        val attempt = bindAttempts.begin()
        if (attempt != null) {
            Phase4Mark.emit(
                "vpn_remote_bind_begin",
                mapOf("service" to intent.component?.className),
            )
            job?.cancel()
            job = null
            _serviceState.value = null
            job = launch {
                val terminalResult = runCatching {
                    GlobalState.application.bindServiceFlow<IBinder>(intent)
                        .takeWhile { handleBind(attempt, it) }
                        .collect {}
                }
                unexpectedBindTerminalMessage(bindAttempts, attempt, terminalResult)?.let { message ->
                    _serviceState.value = Pair(null, message)
                    onServiceDisconnected?.invoke(message)
                }
            }
        }
    }

    suspend inline fun <R> useService(
        timeoutMillis: Long = 5000, crossinline block: suspend (T) -> R
    ): Result<R> {
        return runCatching {
            withTimeout(timeoutMillis) {
                val state = serviceState.filterNotNull().first()
                state.first?.let {
                    withContext(Dispatchers.Default) {
                        block(it)
                    }
                } ?: throw Exception(state.second)
            }
        }
    }

    fun unbind() {
        val invalidated = bindAttempts.invalidate()
        if (invalidated) {
            Phase4Mark.emit(
                "vpn_remote_unbound",
                mapOf("service" to intent.component?.className),
            )
        }
        job?.cancel()
        job = null
        _serviceState.value = null
    }
}
