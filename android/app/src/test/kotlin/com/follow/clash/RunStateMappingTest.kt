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
}
