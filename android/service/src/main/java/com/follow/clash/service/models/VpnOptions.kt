package com.follow.clash.service.models

import android.os.Parcelable
import com.follow.clash.common.AccessControlMode
import kotlinx.parcelize.Parcelize
import java.net.InetAddress

@Parcelize
data class AccessControlProps(
    val enable: Boolean,
    val mode: AccessControlMode,
    val acceptList: List<String>,
    val rejectList: List<String>,
) : Parcelable

@Parcelize
data class VpnOptions(
    val enable: Boolean,
    val port: Int,
    val ipv6: Boolean,
    val dnsHijacking: Boolean,
    val accessControlProps: AccessControlProps,
    val allowBypass: Boolean,
    val systemProxy: Boolean,
    val bypassDomain: List<String>,
    val stack: String,
    val routeAddress: List<String>,
) : Parcelable

data class CIDR(val address: InetAddress, val prefixLength: Int)

const val TUN_DNS_V4 = "172.19.0.2"
const val TUN_DNS_V6 = "fdfe:dcba:9876::2"
const val TUN_DNS_ANY_V4 = "0.0.0.0"
const val TUN_DNS_ANY_V6 = "::"

/// Always hijack UDP/53 on TUN, not only the VPN DNS address.
/// Xiaomi SmartDns and Private DNS ignore VpnService addDnsServer and query
/// other resolvers through the tunnel; without 0.0.0.0:53 those lookups
/// black-hole for several seconds after connect.
fun tunDnsHijackServers(ipv6: Boolean): String {
    val parts = mutableListOf(TUN_DNS_ANY_V4, TUN_DNS_V4)
    if (ipv6) {
        parts += TUN_DNS_ANY_V6
        parts += TUN_DNS_V6
    }
    return parts.joinToString(",")
}

/// VpnService must not publish `127.0.0.1` as the VPN HTTP proxy.
///
/// [android.net.VpnService.Builder.setHttpProxy] attaches one ProxyInfo to
/// every UID on the VPN, including Xiaomi XSpace / clone apps. Those users
/// receive `127.0.0.1:mixed-port` but cannot connect to the owner user's
/// loopback, so OkHttp / WebView / XWeb hang in SYN_SENT. TUN already
/// intercepts the same traffic. The in-app system-proxy switch is left
/// unchanged; this only skips attaching localhost on the VPN builder.
@Suppress("UNUSED_PARAMETER")
fun shouldAttachVpnHttpProxy(systemProxyRequested: Boolean): Boolean = false

fun VpnOptions.getIpv4RouteAddress(): List<CIDR> {
    return routeAddress.filter {
        it.isIpv4()
    }.map {
        it.toCIDR()
    }
}

fun VpnOptions.getIpv6RouteAddress(): List<CIDR> {
    return routeAddress.filter {
        it.isIpv6()
    }.map {
        it.toCIDR()
    }
}

fun String.isIpv4(): Boolean {
    val parts = split("/")
    if (parts.size != 2) {
        throw IllegalArgumentException("Invalid CIDR format")
    }
    val address = InetAddress.getByName(parts[0])
    return address.address.size == 4
}

fun String.isIpv6(): Boolean {
    val parts = split("/")
    if (parts.size != 2) {
        throw IllegalArgumentException("Invalid CIDR format")
    }
    val address = InetAddress.getByName(parts[0])
    return address.address.size == 16
}

fun String.toCIDR(): CIDR {
    val parts = split("/")
    if (parts.size != 2) {
        throw IllegalArgumentException("Invalid CIDR format")
    }
    val ipAddress = parts[0]
    val prefixLength =
        parts[1].toIntOrNull() ?: throw IllegalArgumentException("Invalid prefix length")

    val address = InetAddress.getByName(ipAddress)

    val maxPrefix = if (address.address.size == 4) 32 else 128
    if (prefixLength < 0 || prefixLength > maxPrefix) {
        throw IllegalArgumentException("Invalid prefix length for IP version")
    }

    return CIDR(address, prefixLength)
}