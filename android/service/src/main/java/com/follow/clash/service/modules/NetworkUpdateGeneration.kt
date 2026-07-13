package com.follow.clash.service.modules

import java.util.concurrent.atomic.AtomicLong

internal class NetworkUpdateGeneration {
    private val value = AtomicLong(0L)

    fun next(): Long = value.incrementAndGet()

    fun isCurrent(generation: Long): Boolean = generation == value.get()
}

internal fun normalizeDnsServers(servers: List<String>): List<String> =
    servers.filter { it.isNotBlank() }.distinct()
