package com.follow.clash.service

import com.follow.clash.service.models.ServiceErrorCode
import com.follow.clash.service.models.ServiceOperationResult
import com.follow.clash.service.models.SessionState
import com.follow.clash.service.models.SessionTransitions
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class RemoteSessionHealthTest {
    @Test
    fun runningSnapshotRequiresOperationalService() {
        assertTrue(canReuseRunningSession(SessionState.RUNNING, operational = true))
        assertFalse(canReuseRunningSession(SessionState.RUNNING, operational = false))
        assertFalse(canReuseRunningSession(SessionState.STOPPED, operational = true))
    }

    @Test
    fun operationalRunningExplicitStartReusesExistingSession() {
        val running = SessionTransitions.running(SessionTransitions.starting(7L, 10L))

        assertTrue(canReuseRunningSession(running.state, operational = true))
        assertEquals(7L, running.sessionId)
        assertEquals(10L, running.startedAt)
    }

    @Test
    fun revokeOnlyStopsTheSessionThatLostOwnership() {
        val revoked = SessionTransitions.running(SessionTransitions.starting(7L, 10L))
        val replacement = SessionTransitions.running(SessionTransitions.starting(8L, 20L))

        assertTrue(shouldStopRevokedSession(7L, revoked))
        assertFalse(shouldStopRevokedSession(7L, replacement))
        assertFalse(shouldStopRevokedSession(0L, revoked))
    }

    @Test
    fun physicalServiceDisconnectIsTerminal() {
        val snapshot = disconnectedSessionSnapshot("binder died")

        assertEquals(SessionState.STOPPED, snapshot.state)
        assertEquals(ServiceErrorCode.SERVICE_DISCONNECTED, snapshot.lastErrorCode)
        assertEquals("binder died", snapshot.lastErrorMessage)
    }

    @Test
    fun cleanupFailureKeepsStoppingSnapshotAndRecoveryDelegate() {
        val current = SessionTransitions.stopping(
            SessionTransitions.running(SessionTransitions.starting(7L, 10L)),
        )
        val resolution = cleanupResolution(
            current,
            ServiceOperationResult.failure(ServiceErrorCode.SERVICE_DISCONNECTED, "timeout"),
        )

        assertEquals(SessionState.STOPPING, resolution.snapshot.state)
        assertEquals(7L, resolution.snapshot.sessionId)
        assertFalse(resolution.clearDelegate)
    }

    @Test
    fun secondCleanupAttemptCanClearSameDelegateAfterSuccess() {
        val stopping = cleanupResolution(
            SessionTransitions.stopping(
                SessionTransitions.running(SessionTransitions.starting(7L, 10L)),
            ),
            ServiceOperationResult.failure(ServiceErrorCode.SERVICE_DISCONNECTED, "timeout"),
        )
        val completed = cleanupResolution(
            stopping.snapshot,
            ServiceOperationResult.success(),
        )

        assertFalse(stopping.clearDelegate)
        assertTrue(completed.clearDelegate)
        assertEquals(SessionState.STOPPED, completed.snapshot.state)
    }

    @Test
    fun failedStartRollbackRetainsCleanupActor() {
        val starting = SessionTransitions.starting(11L, 20L)
        val resolution = cleanupResolution(
            starting,
            ServiceOperationResult.failure(ServiceErrorCode.TUN_START_FAILED, "rollback failed"),
        )

        assertEquals(SessionState.STOPPING, resolution.snapshot.state)
        assertEquals(11L, resolution.snapshot.sessionId)
        assertFalse(resolution.clearDelegate)
    }

    @Test
    fun retainedCleanupActorCanConvergeThroughPhysicalDisconnect() {
        val stopped = disconnectedSessionSnapshot("physical service disconnected")

        assertEquals(SessionState.STOPPED, stopped.state)
        assertEquals(ServiceErrorCode.SERVICE_DISCONNECTED, stopped.lastErrorCode)
    }

    @Test
    fun staleDelegateGenerationCannotOverwriteReplacementSession() {
        assertFalse(isCurrentDelegateGeneration(callbackGeneration = 3L, currentGeneration = 4L))
        assertTrue(isCurrentDelegateGeneration(callbackGeneration = 4L, currentGeneration = 4L))
    }
}
