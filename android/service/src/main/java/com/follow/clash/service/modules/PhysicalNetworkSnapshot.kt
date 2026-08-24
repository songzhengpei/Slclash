package com.follow.clash.service.modules

/** A privacy-preserving view of the current non-VPN network. */
data class PhysicalNetworkSnapshot(
    val generation: Long,
    val networkId: Long?,
    val transport: String,
    val ipv4Addresses: List<String>,
    val dnsServers: List<String>,
    val timestamp: Long = System.currentTimeMillis(),
) {
    val isKnown: Boolean get() = networkId != null && ipv4Addresses.isNotEmpty()
}

internal fun physicalNetworkRank(transport: String, available: Boolean): Int {
    val transportRank = when (transport) {
        "wifi" -> 0
        "ethernet" -> 1
        "usb" -> 2
        "bluetooth" -> 3
        "cellular" -> 4
        "satellite" -> 5
        else -> 20
    }
    return transportRank + if (available) 0 else 10
}

/**
 * Process-local fan-out for the single ConnectivityManager observer.
 * The remote service registers the lifecycle consumer; DNS remains local to
 * NetworkObserveModule. The last snapshot is replayed after service recreation.
 */
object PhysicalNetworkControlPlane {
    @Volatile private var latest: PhysicalNetworkSnapshot? = null
    @Volatile private var consumer: ((PhysicalNetworkSnapshot) -> Unit)? = null
    @Volatile private var refresher: (suspend () -> PhysicalNetworkSnapshot?)? = null

    fun publish(snapshot: PhysicalNetworkSnapshot) {
        latest = snapshot
        consumer?.invoke(snapshot)
    }

    fun attach(next: (PhysicalNetworkSnapshot) -> Unit) {
        consumer = next
        latest?.let(next)
    }

    fun detach() {
        consumer = null
    }

    fun setRefresher(next: (suspend () -> PhysicalNetworkSnapshot?)?) {
        refresher = next
    }

    suspend fun refresh(): PhysicalNetworkSnapshot? = refresher?.invoke() ?: latest
}
