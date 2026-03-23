package com.follow.clash.common

import com.google.gson.annotations.SerializedName


enum class QuickAction {
    STOP,
    START,
    TOGGLE,
    MODE_RULE,
    MODE_GLOBAL,
    MODE_DIRECT,
}

enum class BroadcastAction {
    SERVICE_CREATED,
    SERVICE_DESTROYED,
    MODE_CHANGED,
}

enum class AccessControlMode {
    @SerializedName("acceptSelected")
    ACCEPT_SELECTED,

    @SerializedName("rejectSelected")
    REJECT_SELECTED,
}