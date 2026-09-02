package com.follow.clash.service.models

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class VpnHttpProxyTest {
    @Test
    fun singleUserDeviceRespectsSystemProxyRequest() {
        assertTrue(
            shouldAttachVpnHttpProxy(
                systemProxyRequested = true,
                hasAssociatedProfiles = false,
            ),
        )
        assertFalse(
            shouldAttachVpnHttpProxy(
                systemProxyRequested = false,
                hasAssociatedProfiles = false,
            ),
        )
    }

    @Test
    fun associatedProfilesAlwaysUseTunOnlyCapture() {
        assertFalse(
            shouldAttachVpnHttpProxy(
                systemProxyRequested = true,
                hasAssociatedProfiles = true,
            ),
        )
        assertFalse(
            shouldAttachVpnHttpProxy(
                systemProxyRequested = false,
                hasAssociatedProfiles = true,
            ),
        )
    }
}
