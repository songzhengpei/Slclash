package com.follow.clash.service

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class VpnRecoveryWatchdogTest {
    @Test
    fun recoveryRequiresCheckpointAndNoTaskRemovalStop() {
        assertTrue(shouldTriggerVpnWatchdogRecovery(false, checkpointValid = true))
        assertFalse(shouldTriggerVpnWatchdogRecovery(true, checkpointValid = true))
        assertFalse(shouldTriggerVpnWatchdogRecovery(false, checkpointValid = false))
    }
}
