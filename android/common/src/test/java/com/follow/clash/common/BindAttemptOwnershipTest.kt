package com.follow.clash.common

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class BindAttemptOwnershipTest {
    @Test
    fun terminalFailureReleasesOwnershipAndAllowsSecondBind() {
        val ownership = BindAttemptOwnership()
        val first = assertNotNull(ownership.begin())

        assertTrue(ownership.release(first))
        assertNotNull(ownership.begin())
    }

    @Test
    fun terminalCompletionWithoutConnectionAllowsSecondBind() {
        val ownership = BindAttemptOwnership()
        val first = assertNotNull(ownership.begin())

        assertTrue(ownership.release(first))
        assertNotNull(ownership.begin())
    }

    @Test
    fun oldAttemptCannotClearNewerBinding() {
        val ownership = BindAttemptOwnership()
        val first = assertNotNull(ownership.begin())
        assertTrue(ownership.release(first))
        val second = assertNotNull(ownership.begin())

        assertFalse(ownership.release(first))
        assertTrue(ownership.isCurrent(second))
        assertNull(ownership.begin())
    }

    @Test
    fun normalDisconnectReleasesExactlyOnceAndAllowsRebind() {
        val ownership = BindAttemptOwnership()
        val first = assertNotNull(ownership.begin())

        assertTrue(ownership.release(first))
        assertFalse(ownership.release(first))
        assertNotNull(ownership.begin())
    }

    @Test
    fun explicitUnbindInvalidatesOldCompletion() {
        val ownership = BindAttemptOwnership()
        val first = assertNotNull(ownership.begin())

        ownership.invalidate()
        val second = assertNotNull(ownership.begin())

        assertFalse(ownership.release(first))
        assertTrue(ownership.isCurrent(second))
    }
}
