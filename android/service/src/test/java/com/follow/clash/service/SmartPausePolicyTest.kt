package com.follow.clash.service

import com.follow.clash.service.models.SessionState
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class SmartPausePolicyTest {
    private val enabled = SmartPauseConfig(true, listOf("192.168.1.0/24"), true)

    @Test
    fun trustedMatcherSupportsExactCidrMultipleAndInvalidRules() {
        assertTrue(TrustedNetworkMatcher.matches("192.168.1.10", "192.168.1.0/24"))
        assertFalse(TrustedNetworkMatcher.matches("192.168.2.10", "192.168.1.0/24"))
        assertTrue(TrustedNetworkMatcher.matches("10.0.0.1", "10.0.0.1"))
        assertTrue(
            TrustedNetworkMatcher.matchesAny(
                listOf("10.1.2.3"),
                listOf("bad", "192.168.0.0/16", "10.0.0.0/8"),
            ),
        )
        assertFalse(TrustedNetworkMatcher.matchesAny(listOf("10.0.0.1"), emptyList()))
        assertFalse(TrustedNetworkMatcher.matches("192.168.1.1", "192.168.1.0/33"))
    }

    @Test
    fun runningOnTrustedNetworkPauses() {
        assertEquals(
            SmartPauseDecision.PAUSE,
            SmartPausePolicy().evaluate(enabled, SessionState.RUNNING, true, true),
        )
    }

    @Test
    fun pausedOffTrustedNetworkResumes() {
        assertEquals(
            SmartPauseDecision.RESUME,
            SmartPausePolicy().evaluate(enabled, SessionState.PAUSED, true, false),
        )
    }

    @Test
    fun manualOverrideSurvivesTrustedEventsAndClearsAfterLeaving() {
        val policy = SmartPausePolicy()
        policy.markManualResume(trusted = true)
        assertEquals(
            SmartPauseDecision.NONE,
            policy.evaluate(enabled, SessionState.RUNNING, true, true),
        )
        assertTrue(policy.manualOverride)
        assertEquals(
            SmartPauseDecision.NONE,
            policy.evaluate(enabled, SessionState.RUNNING, true, false),
        )
        assertFalse(policy.manualOverride)
        assertEquals(
            SmartPauseDecision.PAUSE,
            policy.evaluate(enabled, SessionState.RUNNING, true, true),
        )
    }

    @Test
    fun disablingOrClearingRulesResumesPausedSession() {
        val policy = SmartPausePolicy()
        assertEquals(
            SmartPauseDecision.RESUME,
            policy.evaluate(enabled.copy(enabled = false), SessionState.PAUSED, false, false),
        )
        assertEquals(
            SmartPauseDecision.RESUME,
            policy.evaluate(enabled.copy(trustedNetworks = emptyList()), SessionState.PAUSED, false, false),
        )
    }

    @Test
    fun unknownNetworkNeverChangesLifecycle() {
        val policy = SmartPausePolicy()
        assertEquals(
            SmartPauseDecision.NONE,
            policy.evaluate(enabled, SessionState.PAUSED, false, false),
        )
        assertEquals(
            SmartPauseDecision.NONE,
            policy.evaluate(enabled, SessionState.RUNNING, false, true),
        )
    }
}
