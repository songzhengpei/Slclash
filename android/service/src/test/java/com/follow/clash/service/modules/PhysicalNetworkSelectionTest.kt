package com.follow.clash.service.modules

import com.follow.clash.service.SmartPauseConfig
import com.follow.clash.service.SmartPauseDecision
import com.follow.clash.service.SmartPausePolicy
import com.follow.clash.service.TrustedNetworkMatcher
import com.follow.clash.service.models.SessionState
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class PhysicalNetworkSelectionTest {
    private data class Candidate(
        val handle: Long,
        val transport: String,
        val available: Boolean = true,
        val generalPurpose: Boolean,
        val ipv4Addresses: List<String>,
    )

    private fun select(candidates: Iterable<Candidate>): Candidate? = candidates.minByOrNull {
        physicalNetworkSelectionKey(
            transport = it.transport,
            available = it.available,
            generalPurpose = it.generalPurpose,
            hasIpv4 = it.ipv4Addresses.isNotEmpty(),
            networkHandle = it.handle,
        )
    }

    private val ims = Candidate(
        handle = 101,
        transport = "cellular",
        generalPurpose = false,
        ipv4Addresses = emptyList(),
    )
    private val cmnet = Candidate(
        handle = 165,
        transport = "cellular",
        generalPurpose = true,
        ipv4Addresses = listOf("10.39.6.35"),
    )

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

    @Test
    fun noInternetWifiStillBeatsGeneralPurposeCellular() {
        val wifi = Candidate(
            handle = 200,
            transport = "wifi",
            generalPurpose = false,
            ipv4Addresses = listOf("192.168.1.10"),
        )

        assertEquals(wifi, select(listOf(cmnet, wifi)))
    }

    @Test
    fun normalMobileDataBeatsIms() {
        assertEquals(cmnet, select(listOf(ims, cmnet)))
    }

    @Test
    fun cellularWinnerDoesNotDependOnInsertionOrder() {
        assertEquals(cmnet, select(listOf(ims, cmnet)))
        assertEquals(cmnet, select(listOf(cmnet, ims)))
    }

    @Test
    fun ipv4ReadyCandidateWinsAfterCapabilityTie() {
        val withoutIpv4 = cmnet.copy(handle = 300, ipv4Addresses = emptyList())
        val withIpv4 = cmnet.copy(handle = 301)

        assertEquals(withIpv4, select(listOf(withoutIpv4, withIpv4)))
    }

    @Test
    fun networkHandleMakesEquivalentCandidatesDeterministic() {
        val lowerHandle = cmnet.copy(handle = 400)
        val higherHandle = cmnet.copy(handle = 401)

        assertEquals(lowerHandle, select(listOf(lowerHandle, higherHandle)))
        assertEquals(lowerHandle, select(listOf(higherHandle, lowerHandle)))
    }

    @Test
    fun activeTrustedWifiSnapshotPauses() {
        val wifi = Candidate(
            handle = 500,
            transport = "wifi",
            generalPurpose = false,
            ipv4Addresses = listOf("192.168.1.10"),
        )
        val selected = select(listOf(cmnet, wifi))!!
        val trustedNetworks = listOf("192.168.1.0/24")
        val trusted = TrustedNetworkMatcher.matchesAny(selected.ipv4Addresses, trustedNetworks)

        assertEquals(wifi, selected)
        assertTrue(trusted)
        assertEquals(
            SmartPauseDecision.PAUSE,
            SmartPausePolicy().evaluate(
                SmartPauseConfig(enabled = true, trustedNetworks = trustedNetworks),
                SessionState.RUNNING,
                networkKnown = true,
                trusted = trusted,
            ),
        )
    }

    @Test
    fun pausedSessionResumesAfterWifiLossSelectsNormalMobileData() {
        val selected = select(listOf(ims, cmnet))!!
        val snapshot = PhysicalNetworkSnapshot(
            generation = 1,
            networkId = selected.handle,
            transport = selected.transport,
            ipv4Addresses = selected.ipv4Addresses,
            dnsServers = emptyList(),
        )
        val trustedNetworks = listOf("192.168.1.0/24")
        val trusted = TrustedNetworkMatcher.matchesAny(snapshot.ipv4Addresses, trustedNetworks)

        assertEquals(cmnet, selected)
        assertTrue(snapshot.isKnown)
        assertFalse(trusted)
        assertEquals(
            SmartPauseDecision.RESUME,
            SmartPausePolicy().evaluate(
                SmartPauseConfig(enabled = true, trustedNetworks = trustedNetworks),
                SessionState.PAUSED,
                networkKnown = snapshot.isKnown,
                trusted = trusted,
            ),
        )
    }
}
