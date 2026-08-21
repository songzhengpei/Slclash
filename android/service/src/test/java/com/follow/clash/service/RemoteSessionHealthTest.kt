package com.follow.clash.service

import com.follow.clash.service.models.ServiceErrorCode
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
}
