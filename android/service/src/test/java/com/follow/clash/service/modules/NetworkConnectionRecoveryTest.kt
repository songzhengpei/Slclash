package com.follow.clash.service.modules

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class NetworkConnectionRecoveryTest {
    private fun network(
        id: Long = 1,
        addresses: List<String> = listOf("172.16.150.127"),
        validation: NetworkValidationState = NetworkValidationState(),
    ) = PhysicalNetworkSnapshot(
        generation = 1,
        networkId = id,
        transport = "wifi",
        ipv4Addresses = addresses,
        dnsServers = listOf("218.2.135.1:53"),
        validation = validation,
    )

    private fun NetworkConnectionRecoveryPolicy.observe(
        snapshot: PhysicalNetworkSnapshot?,
    ) = observe(snapshot, closeConnections = true, sessionActive = true)

    @Test
    fun initialValidationAndRepeatedCapabilitiesDoNotDisconnectTraffic() {
        val tracker = NetworkValidationTracker()
        val policy = NetworkConnectionRecoveryPolicy()
        assertNull(policy.observe(network(validation = tracker.state)))
        repeat(5) {
            tracker.update(validated = true, captivePortal = false)
            assertNull(policy.observe(network(validation = tracker.state)))
        }
        assertEquals(0L, tracker.state.recoveryRevision)
    }

    @Test
    fun portalAuthenticationWithSameNetworkAddressAndDnsRecoversExactlyOnce() {
        val tracker = NetworkValidationTracker()
        val policy = NetworkConnectionRecoveryPolicy()
        tracker.update(validated = false, captivePortal = true)
        assertNull(policy.observe(network(validation = tracker.state)))
        tracker.update(validated = false, captivePortal = false)
        assertNull(policy.observe(network(validation = tracker.state)))
        tracker.update(validated = true, captivePortal = false)
        assertEquals(NetworkConnectionRecoveryReason.CAPTIVE_PORTAL_AUTHENTICATED,
            policy.observe(network(validation = tracker.state)))
        repeat(5) {
            tracker.update(validated = true, captivePortal = false)
            assertNull(policy.observe(network(validation = tracker.state)))
        }
        assertEquals(1L, tracker.state.recoveryRevision)
    }

    @Test
    fun recoverySurvivesCoalescedPortalAndValidationLossSnapshots() {
        val tracker = NetworkValidationTracker()
        val policy = NetworkConnectionRecoveryPolicy()
        tracker.update(validated = true, captivePortal = false)
        assertNull(policy.observe(network(validation = tracker.state)))
        // Neither intermediate event reaches RemoteService before the final snapshot.
        tracker.update(validated = false, captivePortal = true)
        tracker.update(validated = true, captivePortal = false)
        assertEquals(NetworkConnectionRecoveryReason.CAPTIVE_PORTAL_AUTHENTICATED,
            policy.observe(network(validation = tracker.state)))
        tracker.update(validated = false, captivePortal = false)
        tracker.update(validated = true, captivePortal = false)
        assertEquals(NetworkConnectionRecoveryReason.VALIDATION_RESTORED,
            policy.observe(network(validation = tracker.state)))
        assertNull(policy.observe(network(validation = tracker.state)))
    }

    @Test
    fun portalStateMustClearBeforeRecoveryEvenIfValidatedIsAlsoReported() {
        val tracker = NetworkValidationTracker()
        tracker.update(validated = false, captivePortal = true)
        tracker.update(validated = true, captivePortal = true)
        assertEquals(0L, tracker.state.recoveryRevision)
        tracker.update(validated = true, captivePortal = false)
        assertEquals(1L, tracker.state.recoveryRevision)
        assertEquals(NetworkConnectionRecoveryReason.CAPTIVE_PORTAL_AUTHENTICATED,
            tracker.state.recoveryReason)
    }

    @Test
    fun aRecoveredThenUnavailableNetworkDoesNotReplayCleanupWhileStillInPortal() {
        val tracker = NetworkValidationTracker()
        val policy = NetworkConnectionRecoveryPolicy()
        tracker.update(validated = true, captivePortal = false)
        policy.observe(network(validation = tracker.state))
        // The consumer sees only the final portal snapshot, after an entire recovery cycle.
        tracker.update(validated = false, captivePortal = false)
        tracker.update(validated = true, captivePortal = false)
        tracker.update(validated = false, captivePortal = true)
        assertNull(policy.observe(network(validation = tracker.state)))
        tracker.update(validated = true, captivePortal = false)
        assertEquals(NetworkConnectionRecoveryReason.CAPTIVE_PORTAL_AUTHENTICATED,
            policy.observe(network(validation = tracker.state)))
        assertNull(policy.observe(network(validation = tracker.state)))
    }

    @Test
    fun losingValidationOnlyRecoversWhenInternetReturns() {
        val tracker = NetworkValidationTracker()
        val policy = NetworkConnectionRecoveryPolicy()
        tracker.update(validated = true, captivePortal = false)
        policy.observe(network(validation = tracker.state))
        repeat(3) {
            tracker.update(validated = false, captivePortal = false)
            assertNull(policy.observe(network(validation = tracker.state)))
        }
        tracker.update(validated = true, captivePortal = false)
        assertEquals(NetworkConnectionRecoveryReason.VALIDATION_RESTORED,
            policy.observe(network(validation = tracker.state)))
        assertNull(policy.observe(network(validation = tracker.state)))
    }

    @Test
    fun localTrustedNetworkRemainsKnownWithoutInternetValidation() {
        val policy = NetworkConnectionRecoveryPolicy()
        val local = network(addresses = listOf("192.168.100.10"))
        assertTrue(local.isKnown)
        assertFalse(local.validation.validated)
        repeat(3) { assertNull(policy.observe(local)) }
    }

    @Test
    fun wifiToCellularAndBackStillCloseOncePerHandover() {
        val policy = NetworkConnectionRecoveryPolicy()
        assertNull(policy.observe(network()))
        val cellular = network(id = 2, addresses = listOf("10.0.0.2")).copy(transport = "cellular")
        assertEquals(NetworkConnectionRecoveryReason.NETWORK_CHANGED, policy.observe(cellular))
        assertNull(policy.observe(cellular))
        assertEquals(NetworkConnectionRecoveryReason.NETWORK_CHANGED, policy.observe(network()))
        assertNull(policy.observe(network()))
    }

    @Test
    fun sameCellularNetworkWithNewAddressRecovers() {
        val policy = NetworkConnectionRecoveryPolicy()
        policy.observe(network(addresses = listOf("10.0.0.2")).copy(transport = "cellular"))
        val renewed = network(addresses = listOf("10.0.0.3")).copy(transport = "cellular")
        assertEquals(NetworkConnectionRecoveryReason.ADDRESS_CHANGED, policy.observe(renewed))
        assertNull(policy.observe(renewed))
    }

    @Test
    fun addressOrderDuplicatesAndUnrelatedSnapshotChangesDoNotDisconnect() {
        val policy = NetworkConnectionRecoveryPolicy()
        policy.observe(network(addresses = listOf("10.0.0.2", "10.0.0.3")))
        assertNull(policy.observe(network(addresses = listOf("10.0.0.3", "10.0.0.2", "10.0.0.2"))
            .copy(generation = 50, timestamp = 999, reason = PhysicalNetworkUpdateReason.APP_FOREGROUND)))
    }

    @Test
    fun temporaryUnknownNetworkRecoversOnceEvenWhenHandleStaysTheSame() {
        val policy = NetworkConnectionRecoveryPolicy()
        policy.observe(network())
        assertNull(policy.observe(null))
        assertNull(policy.observe(network(addresses = emptyList())))
        assertEquals(NetworkConnectionRecoveryReason.NETWORK_RESTORED, policy.observe(network()))
        assertNull(policy.observe(network()))
    }

    @Test
    fun disabledSettingAndInactiveSessionConsumeChangesWithoutClosingLater() {
        for ((enabled, active) in listOf(false to true, true to false)) {
            val policy = NetworkConnectionRecoveryPolicy()
            policy.observe(network())
            val changed = network(id = 2)
            assertNull(policy.observe(changed, closeConnections = enabled, sessionActive = active))
            assertNull(policy.observe(changed))
        }
    }

    @Test
    fun disabledSettingAlsoConsumesPortalRecovery() {
        val tracker = NetworkValidationTracker()
        val policy = NetworkConnectionRecoveryPolicy()
        tracker.update(validated = false, captivePortal = true)
        policy.observe(network(validation = tracker.state))
        tracker.update(validated = true, captivePortal = false)
        val recovered = network(validation = tracker.state)
        assertNull(policy.observe(recovered, closeConnections = false, sessionActive = true))
        assertNull(policy.observe(recovered))
    }

    @Test
    fun newNetworkAndValidationRecoveryInSameSnapshotCauseOnlyOneCleanup() {
        val policy = NetworkConnectionRecoveryPolicy()
        policy.observe(network())
        val tracker = NetworkValidationTracker()
        tracker.update(validated = false, captivePortal = true)
        tracker.update(validated = true, captivePortal = false)
        val next = network(id = 2, validation = tracker.state)
        assertEquals(NetworkConnectionRecoveryReason.NETWORK_CHANGED, policy.observe(next))
        assertNull(policy.observe(next))
    }

    @Test
    fun stoppingSessionClearsTheRecoveryBaseline() {
        val policy = NetworkConnectionRecoveryPolicy()
        policy.observe(network())
        policy.observe(null)
        policy.reset()
        assertNull(policy.observe(network(id = 2)))
    }
}
