package com.follow.clash.service

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ForegroundAppConditionTest {
    private val selected = setOf("app.a", "app.b")
    private fun ForegroundAppCondition.visit(name: String, at: Long) = resumed(name, at, selected, at)

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
