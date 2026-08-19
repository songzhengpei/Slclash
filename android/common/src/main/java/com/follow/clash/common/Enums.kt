package com.follow.clash.common

import com.google.gson.annotations.SerializedName


enum class QuickAction {
    STOP,
    START,
    TOGGLE,
    SMART_STOP,
    SMART_RESUME,
}

enum class BroadcastAction {
    SERVICE_CREATED,
    SERVICE_DESTROYED,
}

enum class AccessControlMode {
    @SerializedName("acceptSelected")
    ACCEPT_SELECTED,

    @SerializedName("rejectSelected")
    REJECT_SELECTED,
}