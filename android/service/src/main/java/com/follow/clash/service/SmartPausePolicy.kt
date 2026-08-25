package com.follow.clash.service

import com.follow.clash.service.modules.PhysicalNetworkSnapshot
import com.follow.clash.service.models.SessionState

data class SmartPauseConfig(
    val enabled: Boolean = false,
    val trustedNetworks: List<String> = emptyList(),
    val closeConnections: Boolean = true,
)

enum class SmartPauseDecision { NONE, PAUSE, RESUME }

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
    it.isKnown && TrustedNetworkMatcher.matchesAny(it.ipv4Addresses, config.trustedNetworks)
} == true

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

    fun evaluate(
        config: SmartPauseConfig,
        sessionState: String,
        networkKnown: Boolean,
        trusted: Boolean,
    ): SmartPauseDecision {
        if (!config.enabled || config.trustedNetworks.isEmpty()) {
            manualOverride = false
            return if (sessionState == SessionState.PAUSED) SmartPauseDecision.RESUME
            else SmartPauseDecision.NONE
        }
        if (!networkKnown) return SmartPauseDecision.NONE
        if (!trusted) {
            manualOverride = false
            return if (sessionState == SessionState.PAUSED) SmartPauseDecision.RESUME
            else SmartPauseDecision.NONE
        }
        return if (sessionState == SessionState.RUNNING && !manualOverride) {
            SmartPauseDecision.PAUSE
        } else SmartPauseDecision.NONE
    }
}
