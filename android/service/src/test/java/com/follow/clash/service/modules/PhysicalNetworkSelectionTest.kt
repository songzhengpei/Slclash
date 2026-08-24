package com.follow.clash.service.modules

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class PhysicalNetworkSelectionTest {
    @Test
    fun activeWifiWinsWhenWifiAndCellularAreSimultaneouslyPresent() {
        assertTrue(
            physicalNetworkRank("wifi", available = true) <
                physicalNetworkRank("cellular", available = true),
        )
    }

    @Test
    fun losingWifiYieldsToActiveCellular() {
        assertTrue(
            physicalNetworkRank("cellular", available = true) <
                physicalNetworkRank("wifi", available = false),
        )
    }

    @Test
    fun localLinkSelectionDoesNotRequireDnsEligibility() {
        // Eligibility is deliberately absent from the physical rank API: a
        // trusted captive/no-internet Wi-Fi remains the Smart Pause primary.
        assertEquals(0, physicalNetworkRank("wifi", available = true))
    }
}
