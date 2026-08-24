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

    @Test
    fun exceptionBeforeConnectionNotifiesOnceAndAllowsFutureBind() {
        val ownership = BindAttemptOwnership()
        val attempt = assertNotNull(ownership.begin())
        var callbacks = 0

        unexpectedBindTerminalMessage(
            ownership,
            attempt,
            Result.failure(IllegalStateException("bind failed")),
        )?.let { message ->
            callbacks += 1
            assertTrue(message.contains("bind failed"))
        }
        unexpectedBindTerminalMessage(ownership, attempt, Result.success(Unit))?.let {
            callbacks += 1
        }

        assertTrue(callbacks == 1)
        assertNotNull(ownership.begin())
    }

    @Test
    fun unexpectedCompletionNotifiesExactlyOnce() {
        val ownership = BindAttemptOwnership()
        val attempt = assertNotNull(ownership.begin())

        val first = unexpectedBindTerminalMessage(ownership, attempt, Result.success(Unit))
        val duplicate = unexpectedBindTerminalMessage(ownership, attempt, Result.success(Unit))

        assertTrue(first == "Service binding ended unexpectedly")
        assertNull(duplicate)
    }

    @Test
    fun emittedDisconnectPreventsCollectorTerminalDoubleCallback() {
        val ownership = BindAttemptOwnership()
        val attempt = assertNotNull(ownership.begin())

        assertTrue(ownership.release(attempt))
        assertNull(unexpectedBindTerminalMessage(ownership, attempt, Result.success(Unit)))
    }

    @Test
    fun explicitUnbindCancellationIsSilent() {
        val ownership = BindAttemptOwnership()
        val attempt = assertNotNull(ownership.begin())

        assertTrue(ownership.invalidate())
        assertNull(
            unexpectedBindTerminalMessage(
                ownership,
                attempt,
                Result.failure(kotlinx.coroutines.CancellationException("owner unbound")),
            ),
        )
    }

    @Test
    fun oldTerminalCannotNotifyOrReleaseNewAttempt() {
        val ownership = BindAttemptOwnership()
        val oldAttempt = assertNotNull(ownership.begin())
        assertTrue(ownership.release(oldAttempt))
        val newAttempt = assertNotNull(ownership.begin())

        assertNull(unexpectedBindTerminalMessage(ownership, oldAttempt, Result.success(Unit)))
        assertTrue(ownership.isCurrent(newAttempt))
    }
}
