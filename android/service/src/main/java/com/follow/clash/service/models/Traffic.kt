package com.follow.clash.service.models

import com.follow.clash.common.GlobalState
import com.follow.clash.common.formatBytes
import com.follow.clash.core.Core
import com.google.gson.Gson

data class Traffic(
    val up: Long,
    val down: Long,
)

data class TrafficSnapshot(
    val up: Long,
    val down: Long,
    val totalUp: Long,
    val totalDown: Long,
)

val Traffic.speedText: String
    get() = "${up.formatBytes}/s↑  ${down.formatBytes}/s↓"

fun Core.getSpeedTrafficText(onlyStatisticsProxy: Boolean): String {
    try {
        val res = getTrafficSnapshot(onlyStatisticsProxy)
        val traffic = Gson().fromJson(res, TrafficSnapshot::class.java)
        return Traffic(up = traffic.up, down = traffic.down).speedText
    } catch (e: Exception) {
        GlobalState.log(e.message + "")
        return ""
    }
}
