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
    private val cellularNetwork = PhysicalNetworkSnapshot(
        generation = 3,
        networkId = 12,
        transport = "cellular",
        ipv4Addresses = emptyList(),
        dnsServers = emptyList(),
    )

    private fun desired(
        current: String,
        network: SmartPausePhysicalNetwork,
        unknownExhausted: Boolean = false,
        recovering: Boolean = false,
        policy: SmartPausePolicy = SmartPausePolicy(),
        config: SmartPauseConfig = enabled,
    ) = policy.desiredState(
        config = config,
        sessionState = current,
        network = network,
        unknownExhausted = unknownExhausted,
        recovering = recovering,
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
    fun physicalNetworkClassificationRequiresConfirmedTrustedWifi() {
        assertEquals(
            SmartPausePhysicalNetwork.TRUSTED_WIFI,
            classifySmartPauseNetwork(trustedNetwork, enabled.trustedNetworks),
        )
        assertEquals(
            SmartPausePhysicalNetwork.UNTRUSTED_WIFI,
            classifySmartPauseNetwork(untrustedNetwork, enabled.trustedNetworks),
        )
        assertEquals(
            SmartPausePhysicalNetwork.CELLULAR,
            classifySmartPauseNetwork(cellularNetwork, enabled.trustedNetworks),
        )
        assertEquals(
            SmartPausePhysicalNetwork.NO_NETWORK,
            classifySmartPauseNetwork(cellularNetwork.copy(networkId = null), enabled.trustedNetworks),
        )
        assertEquals(
            SmartPausePhysicalNetwork.UNKNOWN,
            classifySmartPauseNetwork(null, enabled.trustedNetworks),
        )
        assertEquals(
            SmartPausePhysicalNetwork.UNKNOWN,
            classifySmartPauseNetwork(
                trustedNetwork.copy(transport = "ethernet"),
                enabled.trustedNetworks,
            ),
        )
    }

    @Test
    fun runningToTrustedWifiPauses() {
        val desired = desired(SessionState.RUNNING, SmartPausePhysicalNetwork.TRUSTED_WIFI)
        assertEquals(SmartPauseDesiredState.PAUSED, desired)
        assertEquals(SmartPauseAction.PAUSE, smartPauseActionFor(SessionState.RUNNING, desired))
    }

    @Test
    fun pausedToCellularStartsEvenWithoutIpv4() {
        val desired = desired(SessionState.PAUSED, SmartPausePhysicalNetwork.CELLULAR)
        assertEquals(SmartPauseDesiredState.RUNNING, desired)
        assertEquals(SmartPauseAction.START, smartPauseActionFor(SessionState.PAUSED, desired))
    }

    @Test
    fun pausedToUntrustedWifiStarts() {
        val desired = desired(SessionState.PAUSED, SmartPausePhysicalNetwork.UNTRUSTED_WIFI)
        assertEquals(SmartPauseDesiredState.RUNNING, desired)
        assertEquals(SmartPauseAction.START, smartPauseActionFor(SessionState.PAUSED, desired))
    }

    @Test
    fun missedCallbackForegroundSnapshotStillStartsPausedSession() {
        val foregroundTruth = classifySmartPauseNetwork(cellularNetwork, enabled.trustedNetworks)
        val desired = desired(SessionState.PAUSED, foregroundTruth)
        assertEquals(SmartPauseAction.START, smartPauseActionFor(SessionState.PAUSED, desired))
    }

    @Test
    fun processRecoveryOnCellularStartsRegardlessOfPausedCheckpoint() {
        val desired = desired(
            current = SessionState.STARTING,
            network = SmartPausePhysicalNetwork.CELLULAR,
            recovering = true,
        )
        assertEquals(SmartPauseDesiredState.RUNNING, desired)
        assertEquals(
            SmartPauseAction.START,
            smartPauseActionFor(SessionState.STARTING, desired, recovering = true),
        )
    }

    @Test
    fun processRecoveryStillOnTrustedWifiRemainsPaused() {
        val desired = desired(
            current = SessionState.STARTING,
            network = SmartPausePhysicalNetwork.TRUSTED_WIFI,
            recovering = true,
        )
        assertEquals(SmartPauseDesiredState.PAUSED, desired)
        assertEquals(
            SmartPauseAction.PAUSE,
            smartPauseActionFor(SessionState.STARTING, desired, recovering = true),
        )
    }

    @Test
    fun unknownRetriesThenCellularStarts() {
        assertEquals(
            SmartPauseDesiredState.RETRY,
            desired(SessionState.PAUSED, SmartPausePhysicalNetwork.UNKNOWN),
        )
        assertEquals(
            SmartPauseDesiredState.RUNNING,
            desired(SessionState.PAUSED, SmartPausePhysicalNetwork.CELLULAR),
        )
    }

    @Test
    fun repeatedUnknownFailsSafeToRunning() {
        val desired = desired(
            current = SessionState.PAUSED,
            network = SmartPausePhysicalNetwork.UNKNOWN,
            unknownExhausted = true,
        )
        assertEquals(SmartPauseDesiredState.RUNNING, desired)
        assertEquals(SmartPauseAction.START, smartPauseActionFor(SessionState.PAUSED, desired))
    }

    @Test
    fun repeatedRunningReconcileIsIdempotent() {
        assertEquals(
            SmartPauseAction.NO_ACTION,
            smartPauseActionFor(SessionState.RUNNING, SmartPauseDesiredState.RUNNING),
        )
    }

    @Test
    fun repeatedPausedReconcileIsIdempotent() {
        assertEquals(
            SmartPauseAction.NO_ACTION,
            smartPauseActionFor(SessionState.PAUSED, SmartPauseDesiredState.PAUSED),
        )
    }

    @Test
    fun disablingOrClearingRulesStartsPausedSession() {
        assertEquals(
            SmartPauseDesiredState.RUNNING,
            desired(
                SessionState.PAUSED,
                SmartPausePhysicalNetwork.UNKNOWN,
                config = enabled.copy(enabled = false),
            ),
        )
        assertEquals(
            SmartPauseDesiredState.RUNNING,
            desired(
                SessionState.PAUSED,
                SmartPausePhysicalNetwork.UNKNOWN,
                config = enabled.copy(trustedNetworks = emptyList()),
            ),
        )
    }

    @Test
    fun stoppedSessionIsNeverStartedBySmartPausePolicy() {
        assertEquals(
            SmartPauseDesiredState.NO_ACTION,
            desired(SessionState.STOPPED, SmartPausePhysicalNetwork.CELLULAR),
        )
    }

    @Test
    fun manualOverrideSurvivesTrustedEventsAndClearsAfterLeaving() {
        val policy = SmartPausePolicy()
        policy.markManualResume(trusted = true)
        assertEquals(
            SmartPauseDesiredState.RUNNING,
            desired(
                SessionState.RUNNING,
                SmartPausePhysicalNetwork.TRUSTED_WIFI,
                policy = policy,
            ),
        )
        assertTrue(policy.manualOverride)
        desired(
            SessionState.RUNNING,
            SmartPausePhysicalNetwork.CELLULAR,
            policy = policy,
        )
        assertFalse(policy.manualOverride)
        assertEquals(
            SmartPauseDesiredState.PAUSED,
            desired(
                SessionState.RUNNING,
                SmartPausePhysicalNetwork.TRUSTED_WIFI,
                policy = policy,
            ),
        )
    }

    @Test
    fun manualResumeRequiresTrustedWifiNotJustMatchingIp() {
        assertTrue(manualResumeTrusted(PausedResumeSource.USER, trustedNetwork, enabled))
        assertFalse(
            manualResumeTrusted(
                PausedResumeSource.USER,
                trustedNetwork.copy(transport = "ethernet"),
                enabled,
            ),
        )
        assertFalse(manualResumeTrusted(PausedResumeSource.USER, untrustedNetwork, enabled))
        assertFalse(manualResumeTrusted(PausedResumeSource.POLICY, trustedNetwork, enabled))
    }

    @Test
    fun retryScheduleCountsOnlyExecutedRetries() {
        val retries = BoundedRetrySchedule(longArrayOf(500L, 1_500L, 3_000L))
        repeat(4) { assertEquals(500L, retries.nextDelay()) }
        assertEquals(0, retries.executedAttempts)
        retries.markExecuted()
        assertEquals(1_500L, retries.nextDelay())
        retries.markExecuted()
        assertEquals(3_000L, retries.nextDelay())
        retries.markExecuted()
        assertEquals(null, retries.nextDelay())
    }
}
