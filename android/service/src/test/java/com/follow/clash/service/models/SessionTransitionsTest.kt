package com.follow.clash.service.models

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class SessionTransitionsTest {
    @Test
    fun sessionIdentitySurvivesPauseAndResume() {
        val starting = SessionTransitions.starting(sessionId = 42L, startedAt = 100L)
        val running = SessionTransitions.running(starting)
        val paused = SessionTransitions.paused(running)
        val resumed = SessionTransitions.running(paused)

        assertEquals(SessionState.STARTING, starting.state)
        assertEquals(SessionState.RUNNING, running.state)
        assertEquals(SessionState.PAUSED, paused.state)
        assertTrue(paused.smartPaused)
        assertEquals(42L, resumed.sessionId)
        assertEquals(100L, resumed.startedAt)
        assertFalse(resumed.smartPaused)
    }

    @Test
    fun stoppingKeepsCurrentSessionUntilCleanupCompletes() {
        val running = SessionTransitions.running(SessionTransitions.starting(7L, 9L))
        val stopping = SessionTransitions.stopping(running)

        assertEquals(SessionState.STOPPING, stopping.state)
        assertEquals(7L, stopping.sessionId)
    }

    @Test
    fun activeStatesKeepRemoteServiceAfterUiUnbind() {
        assertTrue(SessionState.keepsRemoteService(SessionState.RUNNING))
        assertTrue(SessionState.keepsRemoteService(SessionState.PAUSED))
        assertTrue(SessionState.keepsRemoteService(SessionState.STARTING))
        assertTrue(SessionState.keepsRemoteService(SessionState.STOPPING))
        assertFalse(SessionState.keepsRemoteService(SessionState.STOPPED))
    }
}
