package com.follow.clash.service.modules

import android.app.Notification.FOREGROUND_SERVICE_IMMEDIATE
import android.app.PendingIntent
import android.app.Service
import android.app.Service.STOP_FOREGROUND_REMOVE
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.content.getSystemService
import com.follow.clash.common.Components
import com.follow.clash.common.GlobalState
import com.follow.clash.common.QuickAction
import com.follow.clash.common.action
import com.follow.clash.common.receiveBroadcastFlow
import com.follow.clash.common.startForeground
import com.follow.clash.common.tickerFlow
import com.follow.clash.common.toPendingIntent
import com.follow.clash.core.Core
import com.follow.clash.service.R
import com.follow.clash.service.State
import com.follow.clash.service.models.NotificationParams
import com.follow.clash.service.models.getSpeedTrafficText
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onStart
import kotlinx.coroutines.launch

data class ExtendedNotificationParams(
    val title: String,
    val onlyStatisticsProxy: Boolean,
    val contentText: String,
    val currentMode: String,
    val ruleText: String,
    val globalText: String,
    val directText: String,
)

val NotificationParams.extended: ExtendedNotificationParams
    get() = ExtendedNotificationParams(
        title, onlyStatisticsProxy, Core.getSpeedTrafficText(onlyStatisticsProxy),
        currentMode, ruleText, globalText, directText
    )

class NotificationModule(private val service: Service) : Module() {
    private val scope = CoroutineScope(Dispatchers.Default)

    private fun modeBroadcastPendingIntent(action: QuickAction): PendingIntent {
        val intent = Intent(action.action).setPackage(GlobalState.packageName)
        return PendingIntent.getBroadcast(
            service,
            action.ordinal,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    private fun changeModeViaCore(mode: String) {
        Core.invokeAction(
            """{"id":"changeMode#${System.currentTimeMillis()}","method":"updateConfig","data":"{\"mode\":\"$mode\"}"}"""
        ) {}
        val currentParams = State.notificationParamsFlow.value
        if (currentParams != null) {
            State.notificationParamsFlow.tryEmit(currentParams.copy(currentMode = mode))
        }
    }

    override fun onInstall() {
        scope.launch {
            val screenFlow = service.receiveBroadcastFlow {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
                addAction(QuickAction.MODE_RULE.action)
                addAction(QuickAction.MODE_GLOBAL.action)
                addAction(QuickAction.MODE_DIRECT.action)
            }.map { intent ->
                when (intent.action) {
                    QuickAction.MODE_RULE.action -> { changeModeViaCore("rule"); return@map null }
                    QuickAction.MODE_GLOBAL.action -> { changeModeViaCore("global"); return@map null }
                    QuickAction.MODE_DIRECT.action -> { changeModeViaCore("direct"); return@map null }
                    Intent.ACTION_SCREEN_ON -> true
                    else -> false
                }
            }.onStart {
                emit(isScreenOn())
            }

            val filteredScreenFlow = screenFlow.filterNotNull()

            combine(
                tickerFlow(1000, 0), State.notificationParamsFlow, filteredScreenFlow
            ) { _, params, screenOn ->
                params?.extended to screenOn
            }.filter { (params, screenOn) -> params != null && screenOn }
                .distinctUntilChanged { old, new -> old.first == new.first && old.second == new.second }
                .collect { (params, _) ->
                    update(params!!)
                }

            State.notificationParamsFlow.value?.let {
                update(it.extended)
            } ?: run {
                update(NotificationParams().extended)
            }
        }
    }

    private fun isScreenOn(): Boolean {
        val pm = service.getSystemService<PowerManager>()
        return when (pm != null) {
            true -> pm.isInteractive
            false -> true
        }
    }

    private val notificationBuilder: NotificationCompat.Builder by lazy {
        val intent = Intent().setComponent(Components.MAIN_ACTIVITY)
        with(
            NotificationCompat.Builder(
                service, GlobalState.NOTIFICATION_CHANNEL
            )
        ) {
            setSmallIcon(R.drawable.ic)
            setContentTitle("FlClash")
            setContentIntent(intent.toPendingIntent)
            setPriority(NotificationCompat.PRIORITY_HIGH)
            setCategory(NotificationCompat.CATEGORY_SERVICE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                foregroundServiceBehavior = FOREGROUND_SERVICE_IMMEDIATE
            }
            setOngoing(true)
            setShowWhen(true)
            setOnlyAlertOnce(true)
        }
    }

    private fun currentModeLabel(params: ExtendedNotificationParams): String {
        return when (params.currentMode) {
            "rule" -> params.ruleText
            "global" -> params.globalText
            "direct" -> params.directText
            else -> params.currentMode
        }
    }

    private fun update(params: ExtendedNotificationParams) {
        val contentText = "${currentModeLabel(params)} · ${params.contentText}"
        service.startForeground(
            with(notificationBuilder) {
                setContentTitle(params.title)
                setContentText(contentText)
                setStyle(NotificationCompat.BigTextStyle().bigText(contentText))
                clearActions()
                addAction(
                    0, params.ruleText,
                    modeBroadcastPendingIntent(QuickAction.MODE_RULE)
                )
                addAction(
                    0, params.globalText,
                    modeBroadcastPendingIntent(QuickAction.MODE_GLOBAL)
                )
                addAction(
                    0, params.directText,
                    modeBroadcastPendingIntent(QuickAction.MODE_DIRECT)
                ).build()
            })
    }

    override fun onUninstall() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            service.stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            service.stopForeground(true)
        }
        scope.cancel()
    }
}