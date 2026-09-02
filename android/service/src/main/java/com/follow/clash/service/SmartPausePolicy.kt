package com.follow.clash.service

import com.follow.clash.service.modules.PhysicalNetworkSnapshot
import com.follow.clash.service.models.SessionState

data class SmartPauseConfig(
    val enabled: Boolean = false,
    val trustedNetworks: List<String> = emptyList(),
    val closeConnections: Boolean = true,
)

enum class SmartPausePhysicalNetwork {
    TRUSTED_WIFI,
    UNTRUSTED_WIFI,
    CELLULAR,
    NO_NETWORK,
    UNKNOWN,
}

enum class SmartPauseDesiredState { RUNNING, PAUSED, RETRY, NO_ACTION }

enum class SmartPauseAction { NO_ACTION, PAUSE, START, RETRY }

enum class PausedResumeSource { USER, POLICY, RECOVERY }

/** Counts retries only after their delayed execution actually starts. */
internal class BoundedRetrySchedule(private val delays: LongArray) {
    @Volatile
    var executedAttempts: Int = 0
        private set

    @Synchronized
    fun nextDelay(): Long? = delays.getOrNull(executedAttempts)

    @Synchronized
    fun markExecuted() {
        if (executedAttempts < delays.size) executedAttempts += 1
    }

    @Synchronized
    fun reset() {
        executedAttempts = 0
    }
}

internal fun manualResumeTrusted(
    source: PausedResumeSource,
    network: PhysicalNetworkSnapshot?,
    config: SmartPauseConfig,
): Boolean = source == PausedResumeSource.USER && network?.let {
    it.transport == "wifi" &&
        it.isKnown &&
        TrustedNetworkMatcher.matchesAny(it.ipv4Addresses, config.trustedNetworks)
} == true

internal fun classifySmartPauseNetwork(
    network: PhysicalNetworkSnapshot?,
    trustedNetworks: List<String>,
): SmartPausePhysicalNetwork {
    if (network == null) return SmartPausePhysicalNetwork.UNKNOWN
    if (network.networkId == null) return SmartPausePhysicalNetwork.NO_NETWORK
    if (network.transport == "cellular" || network.transport == "satellite") {
        return SmartPausePhysicalNetwork.CELLULAR
    }
    if (network.transport != "wifi" || network.ipv4Addresses.isEmpty()) {
        return SmartPausePhysicalNetwork.UNKNOWN
    }
    return if (TrustedNetworkMatcher.matchesAny(network.ipv4Addresses, trustedNetworks)) {
        SmartPausePhysicalNetwork.TRUSTED_WIFI
    } else {
        SmartPausePhysicalNetwork.UNTRUSTED_WIFI
    }
}

internal fun smartPauseActionFor(
    currentState: String,
    desiredState: SmartPauseDesiredState,
    recovering: Boolean = false,
): SmartPauseAction {
    if (desiredState == SmartPauseDesiredState.RETRY) return SmartPauseAction.RETRY
    if (desiredState == SmartPauseDesiredState.NO_ACTION) return SmartPauseAction.NO_ACTION
    if (recovering) {
        return if (desiredState == SmartPauseDesiredState.PAUSED) {
            SmartPauseAction.PAUSE
        } else {
            SmartPauseAction.START
        }
    }
    return when {
        currentState == SessionState.RUNNING && desiredState == SmartPauseDesiredState.PAUSED ->
            SmartPauseAction.PAUSE
        currentState == SessionState.PAUSED && desiredState == SmartPauseDesiredState.RUNNING ->
            SmartPauseAction.START
        else -> SmartPauseAction.NO_ACTION
    }
}

object TrustedNetworkMatcher {
    fun matchesAny(addresses: List<String>, networks: List<String>): Boolean =
        addresses.any { address -> networks.any { matches(address, it) } }

    fun matches(address: String, rule: String): Boolean {
        val ip = parseIpv4(address) ?: return false
        val value = rule.trim()
        if (value.isEmpty()) return false
        val parts = value.split('/')
        if (parts.size == 1) return ip == parseIpv4(parts[0])
        if (parts.size != 2) return false
        val network = parseIpv4(parts[0]) ?: return false
        val prefix = parts[1].toIntOrNull() ?: return false
        if (prefix !in 0..32) return false
        if (prefix == 0) return true
        val mask = -1 shl (32 - prefix)
        return ip and mask == network and mask
    }

    internal fun parseIpv4(value: String): Int? {
        val parts = value.trim().split('.')
        if (parts.size != 4) return null
        var result = 0
        for (part in parts) {
            if (part.isEmpty() || (part.length > 1 && part.startsWith('0'))) return null
            val byte = part.toIntOrNull() ?: return null
            if (byte !in 0..255) return null
            result = (result shl 8) or byte
        }
        return result
    }
}

class SmartPausePolicy {
    var manualOverride: Boolean = false
        private set

    fun markManualResume(trusted: Boolean) {
        manualOverride = trusted
    }

    fun onSessionStopped() {
        manualOverride = false
    }

    fun desiredState(
        config: SmartPauseConfig,
        sessionState: String,
        network: SmartPausePhysicalNetwork,
        unknownExhausted: Boolean,
        recovering: Boolean = false,
    ): SmartPauseDesiredState {
        if (!recovering && sessionState != SessionState.RUNNING && sessionState != SessionState.PAUSED) {
            return SmartPauseDesiredState.NO_ACTION
        }
        if (!config.enabled || config.trustedNetworks.isEmpty()) {
            manualOverride = false
            return SmartPauseDesiredState.RUNNING
        }
        return when (network) {
            SmartPausePhysicalNetwork.TRUSTED_WIFI -> {
                if (manualOverride) SmartPauseDesiredState.RUNNING
                else SmartPauseDesiredState.PAUSED
            }
            SmartPausePhysicalNetwork.UNKNOWN -> {
                if (!recovering && sessionState == SessionState.RUNNING) {
                    SmartPauseDesiredState.RUNNING
                } else if (unknownExhausted) {
                    manualOverride = false
                    SmartPauseDesiredState.RUNNING
                } else {
                    SmartPauseDesiredState.RETRY
                }
            }
            SmartPausePhysicalNetwork.UNTRUSTED_WIFI,
            SmartPausePhysicalNetwork.CELLULAR,
            SmartPausePhysicalNetwork.NO_NETWORK,
            -> {
                manualOverride = false
                SmartPauseDesiredState.RUNNING
            }
        }
    }
}
