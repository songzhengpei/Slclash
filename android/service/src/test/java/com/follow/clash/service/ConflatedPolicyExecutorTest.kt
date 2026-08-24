package com.follow.clash.service

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlin.test.Test
import kotlin.test.assertEquals

class ConflatedPolicyExecutorTest {
    @Test
    fun evaluatorReadsLatestTruthAfterLifecycleGate() = runBlocking {
        val waitingForLock = CompletableDeferred<Unit>()
        val releaseLock = CompletableDeferred<Unit>()
        var latestTruth = "trusted_wifi"
        var evaluatedTruth: String? = null
        val executor = ConflatedPolicyExecutor<String>(this, evaluate = {
            waitingForLock.complete(Unit)
            releaseLock.await()
            // Mirrors RemoteService: read latestPhysicalNetwork only after
            // the lifecycle/runLock gate is acquired.
            evaluatedTruth = latestTruth
        })

        val generation = executor.submit("network")
        waitingForLock.await()
        latestTruth = "cellular"
        releaseLock.complete(Unit)
        executor.await(generation)

        assertEquals("cellular", evaluatedTruth)
        executor.close()
    }

    @Test
    fun rapidRequestsUseOneEvaluatorAndConvergeToLatestValue() = runBlocking {
        val firstStarted = CompletableDeferred<Unit>()
        val releaseFirst = CompletableDeferred<Unit>()
        val evaluated = mutableListOf<String>()
        var active = 0
        var maxActive = 0
        val executor = ConflatedPolicyExecutor<String>(this, evaluate = { value ->
            active += 1
            maxActive = maxOf(maxActive, active)
            if (value == "A") {
                firstStarted.complete(Unit)
                releaseFirst.await()
            }
            evaluated += value
            active -= 1
        })

        executor.submit("A")
        firstStarted.await()
        executor.submit("B")
        val latestGeneration = executor.submit("C")
        releaseFirst.complete(Unit)
        executor.await(latestGeneration)

        assertEquals(listOf("A", "C"), evaluated)
        assertEquals(1, maxActive)
        executor.close()
    }

    @Test
    fun completionBarrierWaitsForRequestedGeneration() = runBlocking {
        val release = CompletableDeferred<Unit>()
        var completed = false
        val executor = ConflatedPolicyExecutor<String>(this, evaluate = {
            release.await()
            completed = true
        })
        val generation = executor.submit("foreground")
        val waiter = async { executor.await(generation) }
        delay(10)
        assertEquals(false, waiter.isCompleted)
        release.complete(Unit)
        waiter.await()
        assertEquals(true, completed)
        executor.close()
    }
}
