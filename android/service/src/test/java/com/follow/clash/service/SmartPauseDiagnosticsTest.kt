package com.follow.clash.service

import kotlin.test.Test
import kotlin.test.assertEquals

class SmartPauseDiagnosticsTest {
    @Test
    fun ringBufferRetainsOnlyNewestEntries() {
        val buffer = BoundedRingBuffer<Int>(3)

        repeat(5, buffer::add)

        assertEquals(listOf(2, 3, 4), buffer.snapshot())
    }
}
