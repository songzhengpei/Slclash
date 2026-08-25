package com.follow.clash.service

import com.follow.clash.service.models.ServiceErrorCode
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class CoreIpcTerminalSemanticsTest {
    @Test
    fun quickSetupNullFailsClosed() {
        val result = quickSetupOperationResult(null)

        assertFalse(result.success)
        assertEquals(ServiceErrorCode.INTERNAL_ERROR, result.errorCode)
    }

    @Test
    fun quickSetupEmptyMessageIsConfirmedSuccess() {
        assertTrue(quickSetupOperationResult("").success)
    }

    @Test
    fun quickSetupInitFailureKeepsSpecificError() {
        val result = quickSetupOperationResult("init failed")

        assertFalse(result.success)
        assertEquals(ServiceErrorCode.CORE_INIT_FAILED, result.errorCode)
    }

    @Test
    fun quickSetupConfigFailureKeepsMihomoMessage() {
        val result = quickSetupOperationResult("invalid config")

        assertFalse(result.success)
        assertEquals(ServiceErrorCode.CONFIG_LOAD_FAILED, result.errorCode)
        assertEquals("invalid config", result.message)
    }
}
