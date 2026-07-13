package com.follow.clash

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.BitmapFactory
import android.graphics.Color
import android.widget.RemoteViews
import com.follow.clash.common.Components
import com.follow.clash.common.GlobalState
import com.follow.clash.common.QuickAction
import com.follow.clash.common.action
import com.follow.clash.common.intent
import com.follow.clash.common.quickIntent
import kotlinx.coroutines.launch
import com.follow.clash.plugins.WidgetPlugin
import com.google.gson.Gson
import java.util.Locale

data class WidgetState(
    val isStart: Boolean = false,
    val mode: String = "rule",
    val groupName: String = "",
    val nodeName: String = "",
    val upSpeed: Number = 0,
    val downSpeed: Number = 0,
    val proxyNames: String = "",
)

object WidgetDataStore {
    private const val PREFS_NAME = "widget_prefs"
    private const val KEY_STATE = "widget_state"
    private const val KEY_LAST_UPDATE = "widget_last_update"
    private const val STALE_TIMEOUT_MS = 300_000L
    private val gson = Gson()

    fun getState(context: Context): WidgetState {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val lastUpdate = prefs.getLong(KEY_LAST_UPDATE, 0)
        if (System.currentTimeMillis() - lastUpdate > STALE_TIMEOUT_MS) {
            return WidgetState()
        }
        val json = prefs.getString(KEY_STATE, null) ?: return WidgetState()
        return try {
            gson.fromJson(json, WidgetState::class.java)
        } catch (_: Exception) {
            WidgetState()
        }
    }

    fun saveState(context: Context, state: WidgetState) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(KEY_STATE, gson.toJson(state))
            .putLong(KEY_LAST_UPDATE, System.currentTimeMillis())
            .apply()
    }

    fun saveStateAsync(context: Context, state: WidgetState) {
        GlobalState.launch {
            saveState(context, state)
        }
    }
}

class WidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_CYCLE_MODE = "com.follow.clash.action.CYCLE_MODE"
        const val ACTION_CYCLE_NODE = "com.follow.clash.action.CYCLE_NODE"
        const val ACTION_SELECT_PROXY = "com.follow.clash.action.SELECT_PROXY"
        const val EXTRA_MODE = "current_mode"

        private fun isChinese(): Boolean {
            return Locale.getDefault().language == "zh"
        }

        private fun formatSpeed(bytes: Number): String {
            val b = bytes.toDouble()
            return when {
                b >= 1_000_000 -> String.format("%.1f MB/s", b / 1_000_000)
                b >= 1_000 -> String.format("%.1f KB/s", b / 1_000)
                else -> String.format("%.0f B/s", b)
            }
        }

        fun buildModeIntent(context: Context): Intent {
            val intent = Intent(context, WidgetProvider::class.java)
            intent.action = ACTION_CYCLE_MODE
            intent.putExtra(EXTRA_MODE, WidgetDataStore.getState(context).mode)
            return intent
        }

        fun buildNodeIntent(context: Context): Intent {
            return QuickAction.SELECT_PROXY.quickIntent
        }

        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, chartBytes: ByteArray? = null) {
            val state = WidgetDataStore.getState(context)
            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            val cn = isChinese()

            // Dark mode
            val isDarkMode = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
            if (isDarkMode) {
                views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_bg_dark)
                views.setInt(R.id.status_row, "setBackgroundResource", R.drawable.widget_ripple_dark)
                views.setInt(R.id.mode_row, "setBackgroundResource", R.drawable.widget_ripple_dark)
                views.setInt(R.id.node_row, "setBackgroundResource", R.drawable.widget_ripple_dark)
                views.setTextColor(R.id.status_text, Color.parseColor("#FFE0E0E0"))
                views.setTextColor(R.id.mode_text, Color.parseColor("#FFE0E0E0"))
                views.setTextColor(R.id.node_text, Color.parseColor("#FFE0E0E0"))
                views.setTextColor(R.id.mode_title, Color.parseColor("#8AFFFFFF"))
                views.setTextColor(R.id.node_title, Color.parseColor("#8AFFFFFF"))
                views.setTextColor(R.id.traffic_text, Color.parseColor("#8AFFFFFF"))
                views.setTextColor(R.id.mode_chevron, Color.parseColor("#8AFFFFFF"))
                views.setTextColor(R.id.node_chevron, Color.parseColor("#8AFFFFFF"))
                views.setInt(R.id.divider1, "setBackgroundColor", Color.parseColor("#1AFFFFFF"))
                views.setInt(R.id.divider2, "setBackgroundColor", Color.parseColor("#1AFFFFFF"))
            } else {
                views.setTextColor(R.id.status_text, Color.BLACK)
                views.setTextColor(R.id.mode_text, Color.BLACK)
                views.setTextColor(R.id.node_text, Color.BLACK)
                views.setTextColor(R.id.mode_title, Color.parseColor("#8A000000"))
                views.setTextColor(R.id.node_title, Color.parseColor("#8A000000"))
                views.setTextColor(R.id.traffic_text, Color.parseColor("#8A000000"))
                views.setTextColor(R.id.mode_chevron, Color.parseColor("#8A000000"))
                views.setTextColor(R.id.node_chevron, Color.parseColor("#8A000000"))
                views.setInt(R.id.divider1, "setBackgroundColor", Color.parseColor("#1A000000"))
                views.setInt(R.id.divider2, "setBackgroundColor", Color.parseColor("#1A000000"))
            }

            // Status
            val statusText = if (state.isStart) {
                if (cn) "运行中" else "Running"
            } else {
                if (cn) "已停止" else "Stopped"
            }
            views.setTextViewText(R.id.status_text, statusText)
            views.setInt(
                R.id.status_icon,
                "setBackgroundResource",
                if (state.isStart) R.drawable.status_dot else R.drawable.status_dot_stopped
            )

            // Power icon
            val powerIcon = if (state.isStart) R.drawable.ic_power_active else R.drawable.ic_power_inactive
            views.setImageViewResource(R.id.toggle_button, powerIcon)

            // Traffic
            val downText = "↓ ${formatSpeed(state.downSpeed)}"
            val upText = "↑ ${formatSpeed(state.upSpeed)}"
            views.setTextViewText(R.id.traffic_text, "$downText  $upText")
            if (chartBytes != null) {
                val bitmap = BitmapFactory.decodeByteArray(chartBytes, 0, chartBytes.size)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.traffic_chart, bitmap)
                }
            }

            // Mode
            val modeLabel = when (state.mode.lowercase(Locale.ROOT)) {
                "rule" -> if (cn) "规则" else "Rule"
                "global" -> if (cn) "全局" else "Global"
                "direct" -> if (cn) "直连" else "Direct"
                else -> state.mode.replaceFirstChar { it.uppercase() }
            }
            val modeTitle = if (cn) "模式" else "Mode"
            views.setTextViewText(R.id.mode_title, modeTitle)
            views.setTextViewText(R.id.mode_text, modeLabel)

            // Node
            val nodeTitle = if (cn) "节点" else "Node"
            views.setTextViewText(R.id.node_title, nodeTitle)
            val nodeLabel = if (state.nodeName.isNotEmpty()) state.nodeName else if (cn) "自动" else "Auto"
            views.setTextViewText(R.id.node_text, nodeLabel)

            // Click handlers - Toggle (Start/Stop)
            val toggleIntent = if (state.isStart) {
                QuickAction.STOP.quickIntent
            } else {
                QuickAction.START.quickIntent
            }
            val togglePendingIntent = PendingIntent.getActivity(
                context,
                0,
                toggleIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            views.setOnClickPendingIntent(R.id.status_row, togglePendingIntent)
            views.setOnClickPendingIntent(R.id.toggle_button, togglePendingIntent)

            // Click handlers - Mode (cycle mode via broadcast)
            val modeIntent = buildModeIntent(context)
            val modePendingIntent = PendingIntent.getBroadcast(
                context,
                1,
                modeIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            views.setOnClickPendingIntent(R.id.mode_row, modePendingIntent)

            // Click handlers - Node (open proxy selection dialog)
            val nodeIntent = buildNodeIntent(context)
            val nodePendingIntent = PendingIntent.getActivity(
                context,
                3,
                nodeIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            views.setOnClickPendingIntent(R.id.node_row, nodePendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_CYCLE_MODE -> handleCycleMode(context)
            ACTION_CYCLE_NODE -> handleCycleNode(context)
            ACTION_SELECT_PROXY -> {
                val proxyName = intent.getStringExtra("selectedProxy") ?: return
                handleSelectProxy(context, proxyName)
            }
        }
    }

    private fun handleCycleMode(context: Context) {
        val flutterEngine = State.flutterEngine
        if (flutterEngine != null) {
            val widgetPlugin = flutterEngine.plugin<WidgetPlugin>()
            widgetPlugin?.handleCycleMode()
        } else {
            val intent = Components.MAIN_ACTIVITY.intent.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            context.startActivity(intent)
        }
    }

    private fun handleCycleNode(context: Context) {
        val flutterEngine = State.flutterEngine
        if (flutterEngine != null) {
            val widgetPlugin = flutterEngine.plugin<WidgetPlugin>()
            widgetPlugin?.handleCycleNode()
        } else {
            val intent = Components.MAIN_ACTIVITY.intent.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            context.startActivity(intent)
        }
    }

    private fun handleSelectProxy(context: Context, proxyName: String) {
        val flutterEngine = State.flutterEngine
        if (flutterEngine != null) {
            val widgetPlugin = flutterEngine.plugin<WidgetPlugin>()
            widgetPlugin?.handleSelectProxy(proxyName)
        } else {
            val intent = Components.MAIN_ACTIVITY.intent.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            context.startActivity(intent)
        }
    }
}
