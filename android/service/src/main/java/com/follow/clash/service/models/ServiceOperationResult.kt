package com.follow.clash.service.models

import android.os.Parcelable
import kotlinx.parcelize.Parcelize

@Parcelize
data class ServiceOperationResult(
    val success: Boolean,
    val runTime: Long = 0L,
    val errorCode: String? = null,
    val message: String? = null,
) : Parcelable {
    companion object {
        fun success(runTime: Long = 0L) = ServiceOperationResult(
            success = true,
            runTime = runTime,
        )

        fun failure(errorCode: String, message: String? = null) = ServiceOperationResult(
            success = false,
            errorCode = errorCode,
            message = message,
        )
    }
}

object ServiceErrorCode {
    const val CORE_INIT_FAILED = "CORE_INIT_FAILED"
    const val CONFIG_LOAD_FAILED = "CONFIG_LOAD_FAILED"
    const val VPN_ESTABLISH_FAILED = "VPN_ESTABLISH_FAILED"
    const val VPN_REVOKED = "VPN_REVOKED"
    const val TUN_START_FAILED = "TUN_START_FAILED"
    const val FOREGROUND_SERVICE_FAILED = "FOREGROUND_SERVICE_FAILED"
    const val SERVICE_DISCONNECTED = "SERVICE_DISCONNECTED"
    const val INTERNAL_ERROR = "INTERNAL_ERROR"
}
