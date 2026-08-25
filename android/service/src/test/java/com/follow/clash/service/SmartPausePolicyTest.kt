package com.follow.clash.service

import com.follow.clash.service.models.SessionState
import com.follow.clash.service.modules.PhysicalNetworkSnapshot
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class SmartPausePolicyTest {
    private val enabled = SmartPauseConfig(true, listOf("192.168.1.0/24"), true)
    private val trustedNetwork = PhysicalNetworkSnapshot(
        generation = 1,
        networkId = 10,
        transport = "wifi",
        ipv4Addresses = listOf("192.168.1.10"),
        dnsServers = emptyList(),
    )
    private val untrustedNetwork = trustedNetwork.copy(
        generation = 2,
        networkId = 11,
        ipv4Addresses = listOf("10.0.0.10"),
    )

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

    @Test
    fun retryScheduleCountsOnlyExecutedRetries() {
        val retries = BoundedRetrySchedule(longArrayOf(500L, 1_500L, 3_000L))

        // Repeated UNKNOWN events merely observe the same pending delay.
        repeat(4) { assertEquals(500L, retries.nextDelay()) }
        assertEquals(0, retries.executedAttempts)

        retries.markExecuted()
        assertEquals(1_500L, retries.nextDelay())
        retries.markExecuted()
        assertEquals(3_000L, retries.nextDelay())
        retries.markExecuted()
        assertEquals(null, retries.nextDelay())
    }

    @Test
    fun userResumeOnTrustedNetworkEnablesManualOverride() {
        assertTrue(manualResumeTrusted(PausedResumeSource.USER, trustedNetwork, enabled))
    }

    @Test
    fun userResumeOnUntrustedNetworkDoesNotEnableManualOverride() {
        assertFalse(manualResumeTrusted(PausedResumeSource.USER, untrustedNetwork, enabled))
    }

    @Test
    fun policyResumeNeverEnablesManualOverride() {
        assertFalse(manualResumeTrusted(PausedResumeSource.POLICY, trustedNetwork, enabled))
    }

    @Test
    fun userResumeOffTrustedThenEnteringTrustedPauses() {
        val policy = SmartPausePolicy()
        policy.markManualResume(
            manualResumeTrusted(PausedResumeSource.USER, untrustedNetwork, enabled),
        )
        assertFalse(policy.manualOverride)
        assertEquals(
            SmartPauseDecision.PAUSE,
            policy.evaluate(enabled, SessionState.RUNNING, networkKnown = true, trusted = true),
        )
    }

    @Test
    fun transientTransitionFailureGetsOneBoundedReevaluationAndThenSucceeds() {
        val retries = BoundedRetrySchedule(longArrayOf(500L, 1_500L, 3_000L))
        var transitionCalls = 0

        fun evaluateLatestPolicy(): Boolean {
            transitionCalls += 1
            return transitionCalls > 1
        }

        assertFalse(evaluateLatestPolicy())
        assertEquals(500L, retries.nextDelay())
        retries.markExecuted()
        assertTrue(evaluateLatestPolicy())
        retries.reset()

        assertEquals(2, transitionCalls)
        assertEquals(0, retries.executedAttempts)
    }
}
