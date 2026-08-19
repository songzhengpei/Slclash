package com.follow.clash.service

import com.follow.clash.common.RunTimeProbe
import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class RunTimeProbeTest {
    @Test
    fun idleStartDoesNotBindWhenRemoteIsDead() {
        assertFalse(
            RunTimeProbe.shouldBindForRunTime(
                remoteProcessAlive = false,
                alreadyBound = false,
                cachedRunTime = 0L,
            ),
        )
    }

    @Test
    fun bindsWhenRemoteProcessIsAlive() {
        assertTrue(
            RunTimeProbe.shouldBindForRunTime(
                remoteProcessAlive = true,
                alreadyBound = false,
                cachedRunTime = 0L,
            ),
        )
    }

    @Test
    fun bindsWhenAlreadyBoundOrCachedRunTime() {
        assertTrue(
            RunTimeProbe.shouldBindForRunTime(
                remoteProcessAlive = false,
                alreadyBound = true,
                cachedRunTime = 0L,
            ),
        )
        assertTrue(
            RunTimeProbe.shouldBindForRunTime(
                remoteProcessAlive = false,
                alreadyBound = false,
                cachedRunTime = 1L,
            ),
        )
    }
}
