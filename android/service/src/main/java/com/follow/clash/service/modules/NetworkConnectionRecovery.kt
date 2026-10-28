package com.follow.clash.service.modules

enum class NetworkConnectionRecoveryReason {
    NETWORK_CHANGED,
    NETWORK_RESTORED,
    ADDRESS_CHANGED,
    CAPTIVE_PORTAL_AUTHENTICATED,
    VALIDATION_RESTORED,
}

data class NetworkValidationState(
    val validated: Boolean = false,
    val captivePortal: Boolean = false,
    val recoveryRevision: Long = 0,
    val recoveryReason: NetworkConnectionRecoveryReason? = null,
)

/** Updated on the observer's serial queue, including updates whose publication is coalesced. */
internal class NetworkValidationTracker {
    var state = NetworkValidationState()
        private set
    private var pendingRecovery: NetworkConnectionRecoveryReason? = null

    fun update(validated: Boolean, captivePortal: Boolean) {
        if (captivePortal) {
            pendingRecovery = NetworkConnectionRecoveryReason.CAPTIVE_PORTAL_AUTHENTICATED
        } else if (state.validated && !validated && pendingRecovery == null) {
            pendingRecovery = NetworkConnectionRecoveryReason.VALIDATION_RESTORED
        }
        val recovery = pendingRecovery.takeIf { validated && !captivePortal }
        state = NetworkValidationState(
            validated = validated,
            captivePortal = captivePortal,
            recoveryRevision = state.recoveryRevision + if (recovery != null) 1 else 0,
            recoveryReason = recovery ?: state.recoveryReason,
        )
        if (recovery != null) pendingRecovery = null
    }
}

/** Consumes path changes once; repeated capabilities/foreground notifications are harmless. */
internal class NetworkConnectionRecoveryPolicy {
    private data class Path(
        val networkId: Long?,
        val addresses: Set<String>,
        val validationRevision: Long,
    )

    private var previous: Path? = null
    private var connectivityGap = false

    fun observe(
        network: PhysicalNetworkSnapshot?,
        closeConnections: Boolean,
        sessionActive: Boolean,
    ): NetworkConnectionRecoveryReason? {
        if (network?.isKnown != true) {
            if (previous != null) connectivityGap = true
            return null
        }
        val current = Path(
            network.networkId,
            network.ipv4Addresses.toSet(),
            network.validation.recoveryRevision,
        )
        val old = previous
        val reason = when {
            old == null -> null
            old.networkId != current.networkId -> NetworkConnectionRecoveryReason.NETWORK_CHANGED
            old.addresses != current.addresses -> NetworkConnectionRecoveryReason.ADDRESS_CHANGED
            current.validationRevision > old.validationRevision &&
                network.validation.validated && !network.validation.captivePortal ->
                network.validation.recoveryReason
            connectivityGap -> NetworkConnectionRecoveryReason.NETWORK_RESTORED
            else -> null
        }
        previous = current
        connectivityGap = false
        // Consume changes while disabled/inactive too, so enabling does not disconnect healthy traffic.
        return reason.takeIf { closeConnections && sessionActive }
    }

    fun reset() {
        previous = null
        connectivityGap = false
    }
}
