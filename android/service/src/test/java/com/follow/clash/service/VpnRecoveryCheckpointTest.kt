package com.follow.clash.service

import com.follow.clash.common.AccessControlMode
import com.follow.clash.service.models.AccessControlProps
import com.follow.clash.service.models.SessionState
import com.follow.clash.service.models.VpnOptions
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class VpnRecoveryCheckpointTest {
    private val options = VpnOptions(
        enable = true,
        port = 7890,
        ipv6 = true,
        dnsHijacking = true,
        accessControlProps = AccessControlProps(
            enable = true,
            mode = AccessControlMode.REJECT_SELECTED,
            acceptList = listOf("com.example.accept"),
            rejectList = listOf("com.example.reject"),
        ),
        allowBypass = false,
        systemProxy = false,
        bypassDomain = listOf("example.com"),
        stack = "mixed",
        routeAddress = listOf("0.0.0.0/0", "::/0"),
    )

    private fun checkpoint(
        state: String = SessionState.RUNNING,
        failures: Int = 0,
        installEpoch: Long = 123L,
    ) = VpnRecoveryCheckpoint(
        installEpoch = installEpoch,
        sessionId = 7L,
        startedAt = 11L,
        state = state,
        setup = QuickSetupPayload("{\"home-dir\":\"/data\"}", "{\"test-url\":\"https://example.com\"}"),
        options = options,
        recoveryFailures = failures,
        updatedAt = 13L,
    )

    @Test
    fun checkpointRoundTripsAllExplicitVpnFields() {
        val source = checkpoint(state = SessionState.PAUSED)

        val decoded = VpnRecoveryCheckpointCodec.decode(
            VpnRecoveryCheckpointCodec.encode(source),
        )

        assertEquals(source, decoded)
    }

    @Test
    fun corruptedOrUnsupportedCheckpointFailsClosed() {
        assertNull(VpnRecoveryCheckpointCodec.decode("not-json"))
        val unsupported = VpnRecoveryCheckpointCodec.encode(
            checkpoint().copy(schemaVersion = VPN_RECOVERY_SCHEMA_VERSION + 1),
        )
        assertNull(VpnRecoveryCheckpointCodec.decode(unsupported))
        assertNull(
            VpnRecoveryCheckpointCodec.decode(
                VpnRecoveryCheckpointCodec.encode(
                    checkpoint().copy(options = options.copy(enable = false)),
                )
            )
        )
    }

    @Test
    fun installChangeAndExhaustedFailuresInvalidateRecovery() {
        assertTrue(isCheckpointCompatible(checkpoint(), installEpoch = 123L))
        assertFalse(isCheckpointCompatible(checkpoint(), installEpoch = 124L))
        assertFalse(
            isCheckpointCompatible(
                checkpoint(failures = VPN_RECOVERY_MAX_FAILURES),
                installEpoch = 123L,
            )
        )
    }

    @Test
    fun explicitStopAlwaysOverridesStickyCheckpoint() {
        assertTrue(shouldKeepVpnServiceSticky(forceNonSticky = false, checkpointValid = true))
        assertFalse(shouldKeepVpnServiceSticky(forceNonSticky = true, checkpointValid = true))
        assertFalse(shouldKeepVpnServiceSticky(forceNonSticky = false, checkpointValid = false))
    }

    @Test
    fun onlyNullIntentSchedulesOneRecoveryActor() {
        assertTrue(
            shouldStartStickyRecovery(
                intentIsNull = true,
                checkpointValid = true,
                recoveryAlreadyActive = false,
            )
        )
        assertFalse(
            shouldStartStickyRecovery(
                intentIsNull = false,
                checkpointValid = true,
                recoveryAlreadyActive = false,
            )
        )
        assertFalse(
            shouldStartStickyRecovery(
                intentIsNull = true,
                checkpointValid = true,
                recoveryAlreadyActive = true,
            )
        )
    }

    @Test
    fun persistedSharedStateSuppliesSetupWhenCoreWasAlreadyInitialized() {
        val payload = quickSetupPayloadFromSharedState(
            rawSharedState = """{"setupParams":{"selected-map":{"GLOBAL":"Proxy"},"test-url":"https://example.com"},"vpnOptions":{}}""",
            homeDir = "/data/user/0/app/files",
            sdkInt = 37,
        )

        assertEquals(
            "{\"home-dir\":\"/data/user/0/app/files\",\"version\":37}",
            payload?.initParamsJson,
        )
        assertEquals(
            "{\"selected-map\":{\"GLOBAL\":\"Proxy\"},\"test-url\":\"https://example.com\"}",
            payload?.setupParamsJson,
        )
        assertNull(
            quickSetupPayloadFromSharedState(
                rawSharedState = "{\"setupParams\":null}",
                homeDir = "/data",
                sdkInt = 37,
            )
        )
    }
}
