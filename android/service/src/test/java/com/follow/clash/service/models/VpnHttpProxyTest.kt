package com.follow.clash.service.models

import kotlin.test.Test
import kotlin.test.assertFalse

class VpnHttpProxyTest {
    @Test
    fun neverAttachesLocalhostProxyEvenWhenRequested() {
        assertFalse(shouldAttachVpnHttpProxy(systemProxyRequested = true))
        assertFalse(shouldAttachVpnHttpProxy(systemProxyRequested = false))
    }
}
