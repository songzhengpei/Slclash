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
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.launch
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress
import java.util.concurrent.ConcurrentHashMap

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
    private val updates = Channel<Long>(Channel.CONFLATED)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var updateJob: Job? = null

    private val request = NetworkRequest.Builder().apply {
        addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
        addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
    }.build()

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            Phase4Mark.emit("network_callback", mapOf("callback" to "available"))
            networkInfos[network] = NetworkInfo()
            enqueueNetworkUpdate()
            super.onAvailable(network)
        }

        override fun onLosing(network: Network, maxMsToLive: Int) {
            Phase4Mark.emit("network_callback", mapOf("callback" to "losing"))
            networkInfos[network]?.losingMs = System.currentTimeMillis() + maxMsToLive
            enqueueNetworkUpdate()
            setUnderlyingNetworks(network)
            super.onLosing(network, maxMsToLive)
        }

        override fun onLost(network: Network) {
            Phase4Mark.emit("network_callback", mapOf("callback" to "lost"))
            networkInfos.remove(network)
            enqueueNetworkUpdate()
            setUnderlyingNetworks(network)
            super.onLost(network)
        }

        override fun onLinkPropertiesChanged(network: Network, linkProperties: LinkProperties) {
            Phase4Mark.emit(
                "network_callback",
                mapOf("callback" to "link_properties", "dns_count" to linkProperties.dnsServers.size),
            )
            networkInfos[network]?.apply {
                dnsList = linkProperties.dnsServers
                ipv4List = linkProperties.linkAddresses.mapNotNull {
                    (it.address as? Inet4Address)?.hostAddress
                }
            }
            enqueueNetworkUpdate()
            setUnderlyingNetworks(network)
            super.onLinkPropertiesChanged(network, linkProperties)
        }
    }


    override suspend fun onInstall() {
        updateJob = scope.launch {
            for (eventGeneration in updates) {
                applyNetworkUpdate(eventGeneration)
            }
        }
        connectivity?.registerNetworkCallback(request, callback)
        PhysicalNetworkControlPlane.setRefresher(::refreshPhysicalNetworks)
        refreshPhysicalNetworks()
    }

    private fun refreshPhysicalNetworks() {
        val manager = connectivity ?: return
        val current = ConcurrentHashMap<Network, NetworkInfo>()
        manager.allNetworks.forEach { network ->
            val capabilities = manager.getNetworkCapabilities(network) ?: return@forEach
            if (!capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN) ||
                !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) ||
                !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
            ) return@forEach
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
        applyNetworkUpdate(generation.next())
    }

    private fun enqueueNetworkUpdate() {
        Phase4Mark.emit("network_update_enqueued")
        updates.trySend(generation.next())
    }

    private fun networkToInt(entry: Map.Entry<Network, NetworkInfo>): Int {
        val capabilities = connectivity?.getNetworkCapabilities(entry.key)
        return when {
            capabilities == null -> 100
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> 90
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> 0
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> 1
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && capabilities.hasTransport(
                TRANSPORT_USB
            ) -> 2

            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH) -> 3
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> 4
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM && capabilities.hasTransport(
                TRANSPORT_SATELLITE
            ) -> 5

            else -> 20
        } + (if (entry.value.isAvailable()) 0 else 10)
    }

    private fun applyNetworkUpdate(eventGeneration: Long) {
        if (!generation.isCurrent(eventGeneration)) {
            Phase4Mark.emit("network_update_skipped", mapOf("reason" to "stale_generation"))
            return
        }
        val primary = networkInfos.asSequence().minByOrNull { networkToInt(it) }
        val dnsList = (primary?.value?.dnsList ?: emptyList()).map { it.asSocketAddressText(53) }
        val capabilities = primary?.key?.let { connectivity?.getNetworkCapabilities(it) }
        val transport = when {
            capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true -> "wifi"
            capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true -> "cellular"
            capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true -> "ethernet"
            else -> "other"
        }
        PhysicalNetworkControlPlane.publish(
            PhysicalNetworkSnapshot(
                generation = eventGeneration,
                networkId = primary?.key?.networkHandle,
                transport = transport,
                ipv4Addresses = primary?.value?.ipv4List ?: emptyList(),
                dnsServers = dnsList,
            )
        )
        if (dnsList.isEmpty() || normalizeDnsServers(dnsList) == preDnsList) {
            Phase4Mark.emit(
                "network_update_skipped",
                mapOf("reason" to if (dnsList.isEmpty()) "empty_dns" else "unchanged_dns"),
            )
            return
        }
        preDnsList = normalizeDnsServers(dnsList)
        Phase4Mark.emit("network_update_applied", mapOf("dns_count" to preDnsList.size))
        Phase4Mark.emit("core_update_dns", mapOf("dns_count" to preDnsList.size))
        Core.updateDNS(preDnsList.joinToString(","))
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
