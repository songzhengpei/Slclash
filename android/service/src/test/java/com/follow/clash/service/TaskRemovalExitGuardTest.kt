package com.follow.clash.service

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class TaskRemovalExitGuardTest {
    @Test
    fun recognizesHyperOsTaskCleanerDescriptionsOnly() {
        assertTrue(isVendorTaskRemovalExit("stop package due to SwipeUpClean"))
        assertTrue(isVendorTaskRemovalExit("OneKeyClean"))
        assertFalse(isVendorTaskRemovalExit("low memory"))
        assertFalse(isVendorTaskRemovalExit(null))
    }
}
