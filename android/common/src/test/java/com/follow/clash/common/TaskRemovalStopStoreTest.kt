package com.follow.clash.common

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class TaskRemovalStopStoreTest {
    @Test
    fun stopMarkerAppliesOnlyToTheBootWhereTaskWasRemoved() {
        assertTrue(isTaskRemovalStopActive(true, markedBootCount = 7, currentBootCount = 7))
        assertFalse(isTaskRemovalStopActive(true, markedBootCount = 7, currentBootCount = 8))
        assertFalse(isTaskRemovalStopActive(false, markedBootCount = 7, currentBootCount = 7))
        assertFalse(isTaskRemovalStopActive(true, markedBootCount = -1, currentBootCount = -1))
    }
}
