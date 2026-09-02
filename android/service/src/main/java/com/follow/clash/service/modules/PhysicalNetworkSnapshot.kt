package com.follow.clash.service.modules

enum class PhysicalNetworkUpdateReason {
    NETWORK_AVAILABLE,
    NETWORK_LOSING,
    NETWORK_LOST,
    NETWORK_CAPABILITIES_CHANGED,
    NETWORK_LINK_PROPERTIES_CHANGED,
    OBSERVER_REGISTERED,
    SERVICE_CREATED,
    PROCESS_RECOVERY,
    APP_FOREGROUND,
    CONFIG_CHANGE,
    UNKNOWN_RETRY,
    EXPLICIT_REFRESH,
}

/** A privacy-preserving view of the current non-VPN network. */
data class PhysicalNetworkSnapshot(
    val generation: Long,
    val networkId: Long?,
    val transport: String,
    val ipv4Addresses: List<String>,
    val dnsServers: List<String>,
    val reason: PhysicalNetworkUpdateReason = PhysicalNetworkUpdateReason.EXPLICIT_REFRESH,
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

internal data class PhysicalNetworkSelectionKey(
    val physicalRank: Int,
    val generalPurposeRank: Int,
    val ipv4ReadinessRank: Int,
    val networkHandle: Long,
) : Comparable<PhysicalNetworkSelectionKey> {
    override fun compareTo(other: PhysicalNetworkSelectionKey): Int =
        compareValuesBy(
            this,
            other,
            PhysicalNetworkSelectionKey::physicalRank,
            PhysicalNetworkSelectionKey::generalPurposeRank,
            PhysicalNetworkSelectionKey::ipv4ReadinessRank,
            PhysicalNetworkSelectionKey::networkHandle,
        )
}

internal fun physicalNetworkSelectionKey(
    transport: String,
    available: Boolean,
    generalPurpose: Boolean,
    hasIpv4: Boolean,
    networkHandle: Long,
): PhysicalNetworkSelectionKey = PhysicalNetworkSelectionKey(
    physicalRank = physicalNetworkRank(transport, available),
    generalPurposeRank = if (generalPurpose) 0 else 1,
    ipv4ReadinessRank = if (hasIpv4) 0 else 1,
    networkHandle = networkHandle,
)

/**
 * Process-local fan-out for the single ConnectivityManager observer.
 * RemoteService owns both the observer and lifecycle consumer so Smart Pause
 * remains observable while the TUN/Core listener is paused. The last snapshot
 * is replayed after service recreation and then replaced by a system refresh.
 */
object PhysicalNetworkControlPlane {
    @Volatile private var latest: PhysicalNetworkSnapshot? = null
    @Volatile private var consumer: ((PhysicalNetworkSnapshot) -> Unit)? = null
    @Volatile private var refresher:
        (suspend (PhysicalNetworkUpdateReason) -> PhysicalNetworkSnapshot?)? = null

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

    fun setRefresher(
        next: (suspend (PhysicalNetworkUpdateReason) -> PhysicalNetworkSnapshot?)?,
    ) {
        refresher = next
    }

    suspend fun refresh(
        reason: PhysicalNetworkUpdateReason = PhysicalNetworkUpdateReason.EXPLICIT_REFRESH,
    ): PhysicalNetworkSnapshot? = refresher?.invoke(reason) ?: latest
}
