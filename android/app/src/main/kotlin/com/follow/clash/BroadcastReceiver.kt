package com.follow.clash

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import com.follow.clash.common.BroadcastAction
import com.follow.clash.common.GlobalState
import com.follow.clash.common.action
import kotlinx.coroutines.launch

class BroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        val ctx = context ?: return
        when (intent?.action) {
            BroadcastAction.SERVICE_CREATED.action -> {
                GlobalState.log("Receiver service created")
                GlobalState.launch {
                    State.handleStartServiceAction()
                }
                val currentState = WidgetDataStore.getState(ctx)
                WidgetDataStore.saveState(ctx, currentState.copy(isStart = true))
                refreshWidget(ctx)
            }

            BroadcastAction.SERVICE_DESTROYED.action -> {
                GlobalState.log("Receiver service destroyed")
                val currentState = WidgetDataStore.getState(ctx)
                WidgetDataStore.saveState(ctx, currentState.copy(isStart = false))
                refreshWidget(ctx)
                GlobalState.launch {
                    State.handleStopServiceAction()
                }
            }
        }
    }

    private fun refreshWidget(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val componentName = ComponentName(context, WidgetProvider::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
        for (appWidgetId in appWidgetIds) {
            WidgetProvider.updateWidget(context, appWidgetManager, appWidgetId)
        }
    }
}