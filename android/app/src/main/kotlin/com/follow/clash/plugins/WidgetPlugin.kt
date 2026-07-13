package com.follow.clash.plugins

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import com.follow.clash.WidgetDataStore
import com.follow.clash.WidgetProvider
import com.follow.clash.WidgetState
import com.follow.clash.common.Components
import com.follow.clash.common.GlobalState
import com.google.gson.Gson
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class WidgetPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val gson = Gson()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
            binding.binaryMessenger, "${Components.PACKAGE_NAME}/widget"
        )
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "updateWidget" -> {
                @Suppress("UNCHECKED_CAST")
                val data = call.arguments as? Map<String, Any?>
                if (data != null) {
                    handleUpdateWidget(data)
                }
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    fun handleCycleMode() {
        channel.invokeMethod("cycleMode", null)
    }

    fun handleCycleNode() {
        channel.invokeMethod("cycleNode", null)
    }

    fun handleSelectProxy(proxyName: String) {
        channel.invokeMethod("selectProxy", proxyName)
    }

    private fun handleUpdateWidget(data: Map<String, Any?>) {
        try {
            val chartBytes = data["chartBytes"] as? ByteArray
            val dataWithoutChart = data.filterKeys { it != "chartBytes" }
            val jsonString = gson.toJson(dataWithoutChart)
            val state = gson.fromJson(jsonString, WidgetState::class.java)
            val context = GlobalState.application
            WidgetDataStore.saveState(context, state)
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, WidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            for (appWidgetId in appWidgetIds) {
                WidgetProvider.updateWidget(context, appWidgetManager, appWidgetId, chartBytes)
            }
        } catch (_: Exception) {
        }
    }
}
