package com.follow.clash.service

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class VpnRecoveryWatchdogTest {
    @Test
    fun recoveryRequiresCheckpointAndNoTaskRemovalStop() {
        assertTrue(shouldRequestVpnProcessRecovery(false, checkpointValid = true))
        assertFalse(shouldRequestVpnProcessRecovery(true, checkpointValid = true))
        assertFalse(shouldRequestVpnProcessRecovery(false, checkpointValid = false))
    }

    @Test
    fun watchdogDeadlineStaysShortEnoughToAvoidMinuteScaleOemDelay() {
        assertTrue(VpnRecoveryWatchdog.RECOVERY_DEADLINE_MILLIS <= 15_000L)
        assertTrue(
            VpnRecoveryWatchdog.HEARTBEAT_INTERVAL_MILLIS <
                VpnRecoveryWatchdog.RECOVERY_DEADLINE_MILLIS,
        )
        assertEquals(
            15_000L,
            nextWatchdogTriggerAt(0L, VpnRecoveryWatchdog.RECOVERY_DEADLINE_MILLIS),
        )
    }
}
