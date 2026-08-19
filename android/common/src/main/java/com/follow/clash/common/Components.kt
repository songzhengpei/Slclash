package com.follow.clash.common

import android.content.ComponentName

object Components {
    const val PACKAGE_NAME = "com.follow.clash"
    const val METHOD_CHANNEL_PREFIX = "com.follow.clash"
    const val APP_CHANNEL = "$METHOD_CHANNEL_PREFIX/app"
    const val SERVICE_CHANNEL = "$METHOD_CHANNEL_PREFIX/service"
    const val TILE_CHANNEL = "$METHOD_CHANNEL_PREFIX/tile"
    const val PHASE4_CHANNEL = "$METHOD_CHANNEL_PREFIX/phase4_perf"

    val MAIN_ACTIVITY =
        ComponentName(GlobalState.packageName, "${PACKAGE_NAME}.MainActivity")

    val TEMP_ACTIVITY =
        ComponentName(GlobalState.packageName, "${PACKAGE_NAME}.TempActivity")

    val BROADCAST_RECEIVER =
        ComponentName(GlobalState.packageName, "${PACKAGE_NAME}.BroadcastReceiver")
}
