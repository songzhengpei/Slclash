package com.follow.clash.service.modules

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class NetworkUpdateGenerationTest {
    @Test
    fun staleGenerationsAreRejected() {
        val generation = NetworkUpdateGeneration()
        val first = generation.next()
        val second = generation.next()

        assertFalse(generation.isCurrent(first))
        assertTrue(generation.isCurrent(second))
    }

    @Test
    fun dnsServersAreDeduplicatedAndBlankValuesRemoved() {
        assertEquals(
            listOf("1.1.1.1:53", "8.8.8.8:53"),
            normalizeDnsServers(listOf("1.1.1.1:53", "", "1.1.1.1:53", "8.8.8.8:53")),
        )
    }
}
