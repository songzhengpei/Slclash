package com.follow.clash

import com.follow.clash.plugins.forwardCoreInvocation
import kotlinx.coroutines.runBlocking
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class CoreInvocationTerminalTest {
    @Test
    fun binderFailureCompletesImmediatelyWithNull() = runBlocking {
        val completions = mutableListOf<String?>()

        forwardCoreInvocation(
            invoke = { Result.failure(IllegalStateException("binder disconnected")) },
            complete = completions::add,
        )

        assertEquals(1, completions.size)
        assertNull(completions.single())
    }

    @Test
    fun unexpectedInvocationThrowCompletesImmediatelyWithNull() = runBlocking {
        val completions = mutableListOf<String?>()

        forwardCoreInvocation(
            invoke = { throw IllegalStateException("invoke failed") },
            complete = completions::add,
        )

        assertEquals(listOf<String?>(null), completions)
    }

    @Test
    fun callbackAndFailureStillCompleteExactlyOnce() = runBlocking {
        val completions = mutableListOf<String?>()

        forwardCoreInvocation(
            invoke = { callback ->
                callback("result")
                Result.failure(IllegalStateException("late failure"))
            },
            complete = completions::add,
        )

        assertEquals(listOf<String?>("result"), completions)
    }

    @Test
    fun emptyCorePayloadBecomesTransportNull() {
        assertNull(completedCorePayload(emptyList()))
        assertNull(completedCorePayload(listOf(byteArrayOf())))
        assertEquals("{}", completedCorePayload(listOf("{}".encodeToByteArray())))
    }
}
