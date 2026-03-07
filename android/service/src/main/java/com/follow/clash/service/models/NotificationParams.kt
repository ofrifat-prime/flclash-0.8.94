package com.follow.clash.service.models

import android.os.Parcelable
import kotlinx.parcelize.Parcelize

@Parcelize
data class NotificationParams(
    val title: String = "FlClash",
    val onlyStatisticsProxy: Boolean = false,
    val currentMode: String = "rule",
    val ruleText: String = "Rule",
    val globalText: String = "Global",
    val directText: String = "Direct",
) : Parcelable