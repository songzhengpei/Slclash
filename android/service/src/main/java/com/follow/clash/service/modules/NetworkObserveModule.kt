package com.follow.clash.service.modules

import android.app.Service
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkCapabilities.TRANSPORT_SATELLITE
import android.net.NetworkCapabilities.TRANSPORT_USB
import android.net.NetworkRequest
import android.os.Build
import androidx.core.content.getSystemService
import com.follow.clash.common.Phase4Mark
import com.follow.clash.core.Core
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.launch
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress
import java.util.concurrent.ConcurrentHashMap

private data class NetworkUpdateRequest(
    val generation: Long,
    val refreshFromSystem: Boolean = false,
    val completion: CompletableDeferred<PhysicalNetworkSnapshot?>? = null,
    val mutation: (() -> Unit)? = null,
)

private data class NetworkInfo(
    @Volatile var losingMs: Long = 0,
    @Volatile var dnsList: List<InetAddress> = emptyList(),
    @Volatile var ipv4List: List<String> = emptyList(),
) {
    fun isAvailable(): Boolean = losingMs < System.currentTimeMillis()
}

class NetworkObserveModule(private val service: Service) : Module() {

    private val networkInfos = ConcurrentHashMap<Network, NetworkInfo>()
    private val connectivity by lazy {
        service.getSystemService<ConnectivityManager>()
    }
    private var preDnsList = listOf<String>()
    private val generation = NetworkUpdateGeneration()
    private val updates = Channel<NetworkUpdateRequest>(Channel.UNLIMITED)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var updateJob: Job? = null
    private val refreshWaiters = mutableListOf<CompletableDeferred<PhysicalNetworkSnapshot?>>()

    // Smart Pause follows physical local-link addresses, including captive or
    // no-internet trusted LANs. DNS eligibility is filtered separately.
    private val request = NetworkRequest.Builder().apply {
        addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
        removeCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
    }.build()

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            Phase4Mark.emit(
                "network_callback",
                mapOf("callback" to "available", "network_id" to network.networkHandle),
            )
            enqueueNetworkUpdate { networkInfos[network] = NetworkInfo() }
            super.onAvailable(network)
        }

        override fun onLosing(network: Network, maxMsToLive: Int) {
            Phase4Mark.emit(
                "network_callback",
                mapOf("callback" to "losing", "network_id" to network.networkHandle),
            )
            enqueueNetworkUpdate {
                networkInfos[network]?.losingMs = System.currentTimeMillis() + maxMsToLive
            }
            setUnderlyingNetworks(network)
            super.onLosing(network, maxMsToLive)
        }

        override fun onLost(network: Network) {
            Phase4Mark.emit(
                "network_callback",
                mapOf("callback" to "lost", "network_id" to network.networkHandle),
            )
            enqueueNetworkUpdate { networkInfos.remove(network) }
            setUnderlyingNetworks(network)
            super.onLost(network)
        }

        override fun onLinkPropertiesChanged(network: Network, linkProperties: LinkProperties) {
            Phase4Mark.emit(
                "network_callback",
                mapOf(
                    "callback" to "link_properties",
                    "network_id" to network.networkHandle,
                    "dns_count" to linkProperties.dnsServers.size,
                ),
            )
            enqueueNetworkUpdate {
                networkInfos.getOrPut(network, ::NetworkInfo).apply {
                    dnsList = linkProperties.dnsServers
                    ipv4List = linkProperties.linkAddresses.mapNotNull {
                        (it.address as? Inet4Address)?.hostAddress
                    }
                }
            }
            setUnderlyingNetworks(network)
            super.onLinkPropertiesChanged(network, linkProperties)
        }

        override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
            Phase4Mark.emit(
                "network_callback",
                mapOf("callback" to "capabilities", "network_id" to network.networkHandle),
            )
            enqueueNetworkUpdate()
            super.onCapabilitiesChanged(network, capabilities)
        }
    }


    override suspend fun onInstall() {
        updateJob = scope.launch {
            for (update in updates) {
                update.completion?.let(refreshWaiters::add)
                update.mutation?.invoke()
                if (update.refreshFromSystem) refreshNetworkInfosFromSystem()
                val snapshot = applyNetworkUpdate(update.generation)
                if (snapshot != null) {
                    refreshWaiters.forEach { it.complete(snapshot) }
                    refreshWaiters.clear()
                }
            }
        }
        connectivity?.registerNetworkCallback(request, callback)
        PhysicalNetworkControlPlane.setRefresher(::requestPhysicalNetworkRefresh)
        requestPhysicalNetworkRefresh()
    }

    private fun refreshNetworkInfosFromSystem() {
        val manager = connectivity ?: return
        val current = ConcurrentHashMap<Network, NetworkInfo>()
        manager.allNetworks.forEach { network ->
            val capabilities = manager.getNetworkCapabilities(network) ?: return@forEach
            if (!capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)) return@forEach
            val properties = manager.getLinkProperties(network)
            current[network] = NetworkInfo(
                dnsList = properties?.dnsServers.orEmpty(),
                ipv4List = properties?.linkAddresses.orEmpty().mapNotNull {
                    (it.address as? Inet4Address)?.hostAddress
                },
            )
        }
        networkInfos.clear()
        networkInfos.putAll(current)
    }

    private suspend fun requestPhysicalNetworkRefresh(): PhysicalNetworkSnapshot? {
        val completion = CompletableDeferred<PhysicalNetworkSnapshot?>()
        val eventGeneration = generation.next()
        updates.send(NetworkUpdateRequest(eventGeneration, refreshFromSystem = true, completion))
        return completion.await()
    }

    private fun enqueueNetworkUpdate(mutation: (() -> Unit)? = null) {
        Phase4Mark.emit("network_update_enqueued")
        updates.trySend(NetworkUpdateRequest(generation.next(), mutation = mutation))
    }

    private fun networkToInt(entry: Map.Entry<Network, NetworkInfo>): Int {
        return physicalNetworkRank(networkTransport(entry.key), entry.value.isAvailable())
    }

    private fun networkTransport(network: Network): String {
        val capabilities = connectivity?.getNetworkCapabilities(network) ?: return "other"
        return when {
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && capabilities.hasTransport(
                TRANSPORT_USB
            ) -> "usb"

            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH) -> "bluetooth"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM && capabilities.hasTransport(
                TRANSPORT_SATELLITE
            ) -> "satellite"

            else -> "other"
        }
    }

    private fun isDnsEligible(network: Network): Boolean {
        val capabilities = connectivity?.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
    }

    private fun applyNetworkUpdate(eventGeneration: Long): PhysicalNetworkSnapshot? {
        if (!generation.isCurrent(eventGeneration)) {
            Phase4Mark.emit("network_update_skipped", mapOf("reason" to "stale_generation"))
            return null
        }
        val physicalPrimary = networkInfos.asSequence().minByOrNull { networkToInt(it) }
        val dnsPrimary = networkInfos.asSequence()
            .filter { isDnsEligible(it.key) }
            .minByOrNull { networkToInt(it) }
        val dnsList = (dnsPrimary?.value?.dnsList ?: emptyList()).map { it.asSocketAddressText(53) }
        val transport = physicalPrimary?.key?.let(::networkTransport) ?: "other"
        val snapshot = PhysicalNetworkSnapshot(
            generation = eventGeneration,
            networkId = physicalPrimary?.key?.networkHandle,
            transport = transport,
            ipv4Addresses = physicalPrimary?.value?.ipv4List ?: emptyList(),
            dnsServers = dnsList,
        )
        // A callback can update generation while the snapshot is assembled.
        // Never publish that stale intermediate view.
        if (!generation.isCurrent(eventGeneration)) {
            Phase4Mark.emit("network_update_skipped", mapOf("reason" to "changed_during_apply"))
            return null
        }
        Phase4Mark.emit(
            "physical_network_selected",
            mapOf(
                "network_generation" to snapshot.generation,
                "network_id" to snapshot.networkId,
                "network_type" to snapshot.transport,
                "network_known" to snapshot.isKnown,
                "ip_count" to snapshot.ipv4Addresses.size,
                "candidate_count" to networkInfos.size,
            ),
        )
        PhysicalNetworkControlPlane.publish(snapshot)
        if (dnsList.isEmpty() || normalizeDnsServers(dnsList) == preDnsList) {
            Phase4Mark.emit(
                "network_update_skipped",
                mapOf("reason" to if (dnsList.isEmpty()) "empty_dns" else "unchanged_dns"),
            )
            return snapshot
        }
        preDnsList = normalizeDnsServers(dnsList)
        Phase4Mark.emit("network_update_applied", mapOf("dns_count" to preDnsList.size))
        Phase4Mark.emit("core_update_dns", mapOf("dns_count" to preDnsList.size))
        Core.updateDNS(preDnsList.joinToString(","))
        return snapshot
    }

    fun setUnderlyingNetworks(network: Network) {
//        if (service is VpnService && Build.VERSION.SDK_INT in 22..28) {
//            service.setUnderlyingNetworks(arrayOf(network))
//        }
    }

    override suspend fun onUninstall() {
        PhysicalNetworkControlPlane.setRefresher(null)
        runCatching { connectivity?.unregisterNetworkCallback(callback) }
        generation.next()
        updates.close()
        updateJob?.cancelAndJoin()
        updateJob = null
        refreshWaiters.forEach { it.cancel() }
        refreshWaiters.clear()
        scope.cancel()
        networkInfos.clear()
        if (preDnsList.isNotEmpty()) {
            preDnsList = emptyList()
            Phase4Mark.emit("core_update_dns", mapOf("dns_count" to 0, "reason" to "uninstall"))
            Core.updateDNS("")
        }
    }
}

fun InetAddress.asSocketAddressText(port: Int): String {
    return when (this) {
        is Inet6Address -> "[${numericToTextFormat(this)}]:$port"

        is Inet4Address -> "${this.hostAddress}:$port"

        else -> throw IllegalArgumentException("Unsupported Inet type ${this.javaClass}")
    }
}

private fun numericToTextFormat(address: Inet6Address): String {
    val src = address.address
    val sb = StringBuilder(39)
    for (i in 0 until 8) {
        sb.append(
            Integer.toHexString(
                src[i shl 1].toInt() shl 8 and 0xff00 or (src[(i shl 1) + 1].toInt() and 0xff)
            )
        )
        if (i < 7) {
            sb.append(":")
        }
    }
    if (address.scopeId > 0) {
        sb.append("%")
        sb.append(address.scopeId)
    }
    return sb.toString()
}
