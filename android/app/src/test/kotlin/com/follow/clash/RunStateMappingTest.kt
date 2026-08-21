package com.follow.clash

import com.follow.clash.service.models.SessionState
import kotlin.test.Test
import kotlin.test.assertEquals

class RunStateMappingTest {
    @Test
    fun sessionStatesKeepExistingRunStateMapping() {
        assertEquals(RunState.START, runStateForSessionState(SessionState.RUNNING))
        assertEquals(RunState.PENDING, runStateForSessionState(SessionState.STARTING))
        assertEquals(RunState.PENDING, runStateForSessionState(SessionState.STOPPING))
        assertEquals(RunState.STOP, runStateForSessionState(SessionState.PAUSED))
        assertEquals(RunState.STOP, runStateForSessionState(SessionState.STOPPED))
        assertEquals(RunState.STOP, runStateForSessionState("UNKNOWN"))
    }

    @Test
    fun toggleUsesAuthoritativeSessionState() {
        assertEquals(SessionCommand.STOP, toggleCommandForSessionState(SessionState.RUNNING))
        assertEquals(SessionCommand.SMART_RESUME, toggleCommandForSessionState(SessionState.PAUSED))
        assertEquals(SessionCommand.START, toggleCommandForSessionState(SessionState.STOPPED))
        assertEquals(SessionCommand.NONE, toggleCommandForSessionState(SessionState.STARTING))
        assertEquals(SessionCommand.NONE, toggleCommandForSessionState(SessionState.STOPPING))
    }

    @Test
    fun fullStopAllowsRunningAndPausedOnly() {
        assertEquals(true, canFullStopSession(SessionState.RUNNING))
        assertEquals(true, canFullStopSession(SessionState.PAUSED))
        assertEquals(false, canFullStopSession(SessionState.STARTING))
        assertEquals(false, canFullStopSession(SessionState.STOPPING))
        assertEquals(false, canFullStopSession(SessionState.STOPPED))
    }
}
