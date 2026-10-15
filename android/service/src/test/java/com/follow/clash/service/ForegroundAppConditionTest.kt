package com.follow.clash.service

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ForegroundAppConditionTest {
    private val selected = setOf("app.a", "app.b")
    private fun ForegroundAppCondition.visit(name: String, at: Long) = resumed(name, at, selected, at)

    @Test fun pollingSlowsOnlyAfterPauseIsConfirmedWithSelectedForeground() {
        val condition = ForegroundAppCondition()
        assertEquals(250L, condition.nextPollDelayMillis(selected, sessionPaused = false))
        // Trusted-network pause without a selected foreground retains normal detection.
        assertEquals(250L, condition.nextPollDelayMillis(selected, sessionPaused = true))
        condition.visit("app.a", 100)
        assertTrue(condition.matches(selected, 100))
        assertEquals(250L, condition.nextPollDelayMillis(selected, sessionPaused = false))
        assertEquals(1_000L, condition.nextPollDelayMillis(selected, sessionPaused = true))
        // A manual resume must keep normal cadence despite the retained app condition.
        assertEquals(250L, condition.nextPollDelayMillis(selected, sessionPaused = false))
    }

    @Test fun slowerDepartureObservationDoesNotExtendThirtySecondWindow() {
        val condition = ForegroundAppCondition()
        condition.visit("app.a", 100)
        assertEquals(1_000L, condition.nextPollDelayMillis(selected, sessionPaused = true))
        // The exit event is read almost a second late; its actual timestamp owns the deadline.
        condition.visit("other", 200)
        assertTrue(condition.matches(selected, 1_100))
        assertEquals(250L, condition.nextPollDelayMillis(selected, sessionPaused = true))
        assertTrue(condition.matches(selected, 30_199))
        assertFalse(condition.matches(selected, 30_200))
    }

    @Test fun selectedSwitchesTransientWindowsAndShortReturnsPreserveCadenceAndGrace() {
        val condition = ForegroundAppCondition()
        condition.visit("app.a", 100)
        condition.visit("app.b", 200)
        condition.visit("com.android.systemui", 300)
        assertEquals(1_000L, condition.nextPollDelayMillis(selected, sessionPaused = true))
        condition.visit("other", 400)
        condition.visit("app.a", 600)
        condition.visit("other", 700)
        assertEquals(250L, condition.nextPollDelayMillis(selected, sessionPaused = true))
        assertTrue(condition.matches(selected, 30_699))
        assertFalse(condition.matches(selected, 30_700))
        condition.reset()
        assertEquals(250L, condition.nextPollDelayMillis(selected, sessionPaused = true))
        condition.visit("app.a", 40_000)
        condition.removeApp("app.a")
        assertEquals(250L, condition.nextPollDelayMillis(selected, sessionPaused = true))
    }

    @Test fun explicitRestartDoesNotReplayPreviousBackgroundWindow() {
        val condition = ForegroundAppCondition(retentionNotBeforeElapsed = 1_000)
        condition.visit("app.a", 100)
        condition.visit("other", 500)
        assertFalse(condition.matches(selected, 1_001))
        // Overlapping queries, unlock reseeding and permission resets keep the boundary.
        val replay = condition.copy()
        replay.reset()
        replay.visit("app.a", 100)
        replay.visit("other", 500)
        replay.freeze(1_002)
        assertFalse(replay.matches(selected, 2_000))
        replay.thaw(2_001)
        assertFalse(replay.matches(selected, 2_001))
        replay.visit("app.b", 2_100)
        replay.visit("other", 2_200)
        assertTrue(replay.matches(selected, 32_199))
        assertFalse(replay.matches(selected, 32_200))
    }

    @Test fun selectedAppStillForegroundAtRestartRemainsATrigger() {
        val condition = ForegroundAppCondition(retentionNotBeforeElapsed = 1_000)
        condition.visit("app.a", 100)
        assertTrue(condition.matches(selected, 1_001))
        condition.removeApp("app.a")
        assertFalse(condition.matches(selected - "app.a", 1_002))
    }

    @Test fun departureAtOrAfterRestartStartsANewWindowEvenInInitialQuery() {
        for (departure in listOf(1_000L, 1_001L)) {
            val condition = ForegroundAppCondition(retentionNotBeforeElapsed = 1_000)
            condition.visit("app.a", 100)
            condition.visit("other", departure)
            assertTrue(condition.matches(selected, departure + 29_999))
            assertFalse(condition.matches(selected, departure + 30_000))
        }
    }

    @Test fun delayedPreRestartDepartureCannotCreateWindowAfterForegroundSeed() {
        val condition = ForegroundAppCondition(retentionNotBeforeElapsed = 1_000)
        condition.visit("app.a", 100)
        assertTrue(condition.matches(selected, 1_001))
        condition.visit("other", 999)
        assertFalse(condition.matches(selected, 1_002))
    }

    @Test fun automaticRecoveryKeepsSameSessionWindowButExcludesPreviousSession() {
        val recovered = ForegroundAppCondition(retentionNotBeforeElapsed = 1_000)
        recovered.visit("app.a", 100)
        recovered.visit("other", 500)
        assertFalse(recovered.matches(selected, 2_000))
        recovered.visit("app.b", 2_100)
        recovered.visit("other", 2_200)
        assertTrue(recovered.matches(selected, 3_000))
        assertFalse(recovered.matches(selected, 32_200))
    }

    @Test fun selectedToSelectedAndTransientDialogsKeepPause() {
        val condition = ForegroundAppCondition()
        condition.visit("app.a", 0)
        assertTrue(condition.matches(selected, 0))
        condition.visit("com.android.systemui", 10)
        condition.visit("com.android.permissioncontroller", 20)
        assertTrue(condition.matches(selected, 60_000))
        condition.visit("app.b", 70_000)
        assertTrue(condition.matches(selected, 120_000))
    }

    @Test fun thirtySecondWindowExpiresInOtherAppIncludingSlclash() {
        val condition = ForegroundAppCondition()
        condition.visit("app.a", 0)
        condition.visit("slclash.test", 100)
        assertTrue(condition.matches(selected, 30_099))
        assertFalse(condition.matches(selected, 30_100))
    }

    @Test fun returnToAnySelectedAppCancelsTimerAndNextDepartureStartsFullWindow() {
        val condition = ForegroundAppCondition()
        condition.visit("app.a", 0)
        condition.visit("other", 100)
        condition.visit("app.b", 29_000)
        assertTrue(condition.matches(selected, 90_000))
        condition.visit("other", 90_100)
        assertTrue(condition.matches(selected, 120_099))
        assertFalse(condition.matches(selected, 120_100))
    }

    @Test fun rapidReturnAndDepartureInOneQueryStillRestartsWindow() {
        val condition = ForegroundAppCondition()
        condition.visit("app.a", 0)
        condition.visit("other", 100)
        condition.visit("app.a", 29_000)
        condition.visit("other", 29_050)
        assertTrue(condition.matches(selected, 59_049))
        assertFalse(condition.matches(selected, 59_050))
    }

    @Test fun unselectedSwitchesAndOverlappingDuplicateQueriesCannotRenewWindow() {
        val condition = ForegroundAppCondition()
        condition.visit("app.a", 0)
        condition.visit("launcher", 100)
        condition.visit("other", 10_000)
        condition.visit("slclash.test", 29_000)
        condition.visit("slclash.test", 29_000)
        condition.visit("app.a", 0)
        assertFalse(condition.matches(selected, 30_100))
    }

    @Test fun oldHistoryDoesNotInventNewWindowButRecentDepartureSurvivesRebuild() {
        val condition = ForegroundAppCondition()
        condition.visit("app.a", 100)
        condition.visit("other", 200)
        assertFalse(condition.matches(selected, 500_000))
        condition.reset()
        condition.visit("app.b", 480_000)
        condition.visit("other", 490_000)
        assertTrue(condition.matches(selected, 500_000))
        assertFalse(condition.matches(selected, 520_000))
    }

    @Test fun lockFreezesRemainingTimeAndUnlockOnlyUsesRemainingWindow() {
        val condition = ForegroundAppCondition()
        condition.visit("app.a", 0)
        condition.visit("other", 100)
        condition.freeze(10_100)
        assertTrue(condition.matches(selected, 1_000_000))
        condition.thaw(1_010_100)
        assertTrue(condition.matches(selected, 1_030_099))
        assertFalse(condition.matches(selected, 1_030_100))
    }

    @Test fun unlockingBackIntoSelectedAppCancelsFrozenTimer() {
        val condition = ForegroundAppCondition()
        condition.visit("app.a", 0)
        condition.visit("other", 100)
        condition.freeze(10_000)
        condition.thaw(1_000_000)
        condition.visit("app.b", 1_000_000)
        assertTrue(condition.matches(selected, 2_000_000))
    }

    @Test fun permissionOrSessionResetAndEmptySelectionReleaseImmediately() {
        val condition = ForegroundAppCondition()
        condition.visit("app.a", 0)
        condition.freeze(100)
        condition.reset()
        assertFalse(condition.matches(selected, 1_000_000))
        condition.visit("app.b", 1_000_001)
        assertFalse(condition.matches(emptySet(), 1_000_002))
    }

    @Test fun uninstallDropsOnlyTheApplicationHoldingTheWindow() {
        val condition = ForegroundAppCondition()
        condition.visit("app.a", 0)
        condition.visit("other", 100)
        condition.removeApp("app.b")
        assertTrue(condition.matches(selected, 1_000))
        condition.removeApp("app.a")
        assertFalse(condition.matches(selected - "app.a", 1_001))
    }

    @Test fun failedPartialQueryCannotChangeConfirmedForeground() {
        val confirmed = ForegroundAppCondition()
        confirmed.visit("app.a", 0)
        val partialQuery = confirmed.copy()
        partialQuery.visit("other", 100)
        assertFalse(partialQuery.matches(selected, 30_100))
        assertTrue(confirmed.matches(selected, 30_100))
    }

    @Test fun clockRollbackWhileLockedResetsCandidateBeforeUnlockReseed() {
        val condition = ForegroundAppCondition()
        val window = ForegroundAppQueryWindow()
        condition.visit("app.a", 100_000)
        window.complete(100_000)
        assertEquals(50_000L - 86_400_000L, window.begin(50_000, true) { condition.reset() })
        condition.visit("other", 50_000)
        assertFalse(condition.matches(selected, 50_000))
        condition.visit("app.b", 50_001)
        assertTrue(condition.matches(selected, 50_001))
    }

    @Test fun ordinaryQueriesOverlapAndUnlockReseedsWithoutDroppingHold() {
        val condition = ForegroundAppCondition()
        val window = ForegroundAppQueryWindow()
        condition.visit("app.a", 10)
        window.complete(100_000)
        assertEquals(98_000L, window.begin(100_250, false) { condition.reset() })
        assertEquals(200_000L - 86_400_000L, window.begin(200_000, true) { condition.reset() })
        assertTrue(condition.matches(selected, 200_000))
    }
}
