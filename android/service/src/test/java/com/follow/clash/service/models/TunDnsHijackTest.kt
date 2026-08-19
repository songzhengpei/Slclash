package com.follow.clash.service.models

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class TunDnsHijackTest {
    @Test
    fun ipv4AlwaysHijacksAnyAndVpnDns() {
        val servers = tunDnsHijackServers(ipv6 = false)
        assertEquals("0.0.0.0,172.19.0.2", servers)
    }

    @Test
    fun ipv6AlsoHijacksAny6AndVpnDns6() {
        val servers = tunDnsHijackServers(ipv6 = true)
        assertEquals("0.0.0.0,172.19.0.2,::,fdfe:dcba:9876::2", servers)
        assertTrue(servers.startsWith("0.0.0.0"))
    }
}
