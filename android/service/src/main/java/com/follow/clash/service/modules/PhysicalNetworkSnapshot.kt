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

/**
 * Process-local fan-out for the single ConnectivityManager observer.
 * The remote service registers the lifecycle consumer; DNS remains local to
 * NetworkObserveModule. The last snapshot is replayed after service recreation.
 */
object PhysicalNetworkControlPlane {
    @Volatile private var latest: PhysicalNetworkSnapshot? = null
    @Volatile private var consumer: ((PhysicalNetworkSnapshot) -> Unit)? = null
    @Volatile private var refresher: (() -> Unit)? = null

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

    fun setRefresher(next: (() -> Unit)?) {
        refresher = next
    }

    fun reevaluate() {
        refresher?.invoke()
        latest?.let { consumer?.invoke(it) }
    }
}
