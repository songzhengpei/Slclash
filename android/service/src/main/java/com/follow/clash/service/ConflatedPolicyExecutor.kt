package com.follow.clash.service

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.launch
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

/** Single-consumer, latest-value policy executor with an awaitable barrier. */
internal class ConflatedPolicyExecutor<T>(
    scope: CoroutineScope,
    private val evaluate: suspend (T) -> Unit,
    private val onError: (Throwable) -> Unit = {},
) {
    private data class Request<T>(val generation: Long, val value: T)

    private val requested = AtomicLong(0L)
    private val processed = AtomicLong(0L)
    private val requests = Channel<Request<T>>(Channel.CONFLATED)
    private val waiters = ConcurrentHashMap<Long, CompletableDeferred<Unit>>()
    private val worker: Job = scope.launch {
        for (request in requests) {
            try {
                evaluate(request.value)
            } catch (error: Throwable) {
                if (error is CancellationException) throw error
                onError(error)
            } finally {
                processed.set(request.generation)
                waiters.entries.forEach { (generation, waiter) ->
                    if (generation <= request.generation && waiters.remove(generation, waiter)) {
                        waiter.complete(Unit)
                    }
                }
            }
        }
    }

    fun submit(value: T): Long {
        val generation = requested.incrementAndGet()
        requests.trySend(Request(generation, value))
        return generation
    }

    suspend fun await(generation: Long) {
        if (processed.get() >= generation) return
        val waiter = CompletableDeferred<Unit>()
        waiters[generation] = waiter
        if (processed.get() >= generation && waiters.remove(generation, waiter)) {
            waiter.complete(Unit)
        }
        waiter.await()
    }

    fun close() {
        requests.close()
        worker.cancel()
        waiters.values.forEach { it.cancel() }
        waiters.clear()
    }
}
