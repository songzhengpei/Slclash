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

    @Test
    fun runningServiceRecordDetectsRemoteProcessAndVpnService() {
        assertTrue(
            RunTimeProbe.runningServiceIndicatesRemote(
                processName = "com.slclash.app.profile:remote",
                servicePackage = "com.other",
                serviceClass = "ignored",
                packageName = "com.slclash.app.profile",
            ),
        )
        assertTrue(
            RunTimeProbe.runningServiceIndicatesRemote(
                processName = "com.slclash.app.profile",
                servicePackage = "com.slclash.app.profile",
                serviceClass = "com.follow.clash.service.VpnService",
                packageName = "com.slclash.app.profile",
            ),
        )
        assertFalse(
            RunTimeProbe.runningServiceIndicatesRemote(
                processName = "com.slclash.app.profile",
                servicePackage = "com.slclash.app",
                serviceClass = "com.follow.clash.service.VpnService",
                packageName = "com.slclash.app.profile",
            ),
        )
    }

    @Test
    fun sessionPresenceRoundTripAndRejectsIncomplete() {
        val encoded = com.follow.clash.common.SessionPresence.encode(
            com.follow.clash.common.RemotePresence(
                pid = 24762,
                state = "RUNNING",
                sessionId = 42L,
                startedAt = 1000L,
                smartPaused = false,
            ),
        )
        val parsed = com.follow.clash.common.SessionPresence.parse(encoded)
        assertTrue(parsed != null)
        assertTrue(parsed!!.pid == 24762)
        assertTrue(parsed.state == "RUNNING")
        assertTrue(parsed.sessionId == 42L)
        assertTrue(com.follow.clash.common.SessionPresence.parse("v1\npid=1\n") == null)
    }

    @Test
    fun hiddenProcMustNotDropARunningPresenceFile() {
        val running = com.follow.clash.common.RemotePresence(
            pid = 1,
            state = "RUNNING",
            sessionId = 1L,
            startedAt = 1L,
            smartPaused = false,
        )
        assertTrue(
            com.follow.clash.common.SessionPresence.shouldTrustRecord(
                running,
                cmdlineReadable = false,
                cmdlineMatches = false,
                pidAlive = true,
            ),
        )
        assertFalse(
            com.follow.clash.common.SessionPresence.shouldDeleteStale(
                running,
                cmdlineReadable = false,
                cmdlineMatches = false,
                pidAlive = true,
            ),
        )
        assertFalse(
            com.follow.clash.common.SessionPresence.shouldTrustRecord(
                running,
                cmdlineReadable = true,
                cmdlineMatches = false,
                pidAlive = true,
            ),
        )
        assertTrue(
            com.follow.clash.common.SessionPresence.shouldDeleteStale(
                running,
                cmdlineReadable = true,
                cmdlineMatches = false,
                pidAlive = true,
            ),
        )
        assertFalse(
            com.follow.clash.common.SessionPresence.shouldTrustRecord(
                running,
                cmdlineReadable = false,
                cmdlineMatches = false,
                pidAlive = false,
            ),
        )
        assertTrue(
            com.follow.clash.common.SessionPresence.shouldDeleteStale(
                running,
                cmdlineReadable = false,
                cmdlineMatches = false,
                pidAlive = false,
            ),
        )
    }

    @Test
    fun cmdlineMatchUsesNulTerminatedProcessName() {
        val raw = "com.slclash.app.profile:remote\u0000extra".toByteArray(Charsets.UTF_8)
        assertTrue(
            RunTimeProbe.cmdlineMatchesProcessName(
                raw,
                "com.slclash.app.profile:remote",
            ),
        )
        assertFalse(
            RunTimeProbe.cmdlineMatchesProcessName(
                raw,
                "com.slclash.app.profile",
            ),
        )
    }
}
