package com.follow.clash.service.modules

import android.Manifest
import android.app.Service
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.os.Build
import androidx.core.content.ContextCompat
import androidx.core.content.getSystemService
import com.follow.clash.common.GlobalState
import com.follow.clash.core.Core
import com.follow.clash.service.State
import com.follow.clash.service.VpnService
import com.google.gson.Gson
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import java.util.UUID

private data class WifiSnapshot(
    val ssid: String?,
    val validated: Boolean,
)

class OnDemandModule(private val service: Service) : Module() {
    private val scope = CoroutineScope(Dispatchers.Default)
    private val connectivity by lazy {
        service.getSystemService<ConnectivityManager>()
    }
    private val wifiManager by lazy {
        service.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
    }
    private val gson = Gson()
    private var updateJob: Job? = null
    private var currentWifiSnapshot: WifiSnapshot? = null
    private var suspended = false
    private var isCallbackRegistered = false
    private var locationPermissionWarningLogged = false
    private var backgroundPermissionWarningLogged = false

    private val request = NetworkRequest.Builder()
        .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
        .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
        .build()

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            scheduleUpdate()
        }

        override fun onCapabilitiesChanged(
            network: Network,
            networkCapabilities: NetworkCapabilities
        ) {
            scheduleUpdate(networkCapabilities)
        }

        override fun onLinkPropertiesChanged(
            network: Network,
            linkProperties: android.net.LinkProperties
        ) {
            scheduleUpdate()
        }

        override fun onLost(network: Network) {
            scheduleUpdate()
        }
    }

    override fun onInstall() {
        scope.launch {
            State.onDemandExcludeSSIDsFlow.collectLatest {
                updateRules(it.toSet())
            }
        }
    }

    override fun onUninstall() {
        unregisterCallback()
        updateJob?.cancel()
        scope.cancel()
    }

    private fun updateRules(excludeSSIDs: Set<String>) {
        if (excludeSSIDs.isEmpty()) {
            unregisterCallback()
            updateJob?.cancel()
            currentWifiSnapshot = null
            if (suspended) {
                setCoreSuspended(false)
            }
            return
        }
        registerCallback()
        scheduleUpdate()
    }

    private fun registerCallback() {
        if (isCallbackRegistered) {
            return
        }
        val manager = connectivity ?: return
        runCatching {
            manager.registerNetworkCallback(request, callback)
            isCallbackRegistered = true
        }.onFailure {
            GlobalState.log("On-demand network callback register failed: ${it.message}")
        }
    }

    private fun unregisterCallback() {
        if (!isCallbackRegistered) {
            return
        }
        runCatching {
            connectivity?.unregisterNetworkCallback(callback)
        }
        isCallbackRegistered = false
    }

    private fun scheduleUpdate(capabilities: NetworkCapabilities? = null) {
        updateJob?.cancel()
        updateJob = scope.launch {
            delay(1500)
            update(capabilities)
        }
    }

    private fun update(capabilities: NetworkCapabilities?) {
        val excludeSSIDs = State.onDemandExcludeSSIDsFlow.value.toSet()
        if (excludeSSIDs.isEmpty()) {
            currentWifiSnapshot = null
            if (suspended) {
                setCoreSuspended(false)
            }
            return
        }
        val wifiSnapshot = getWifiSnapshot(capabilities)
        val shouldSuspend = wifiSnapshot.validated && excludeSSIDs.contains(wifiSnapshot.ssid)
        if (wifiSnapshot == currentWifiSnapshot && suspended == shouldSuspend) {
            return
        }
        currentWifiSnapshot = wifiSnapshot
        GlobalState.log(
            "On-demand SSID: ${wifiSnapshot.ssid ?: "unknown"}, " +
                    "validated: ${wifiSnapshot.validated}, suspended: $shouldSuspend"
        )
        setCoreSuspended(shouldSuspend)
    }

    private fun getWifiSnapshot(capabilities: NetworkCapabilities?): WifiSnapshot {
        if (!hasLocationPermission()) {
            if (!locationPermissionWarningLogged) {
                GlobalState.log("On-demand SSID unavailable: location permission missing")
                locationPermissionWarningLogged = true
            }
            return WifiSnapshot(null, validated = false)
        }
        val directSnapshot = capabilities?.wifiSnapshot()
        if (directSnapshot?.ssid != null) {
            return directSnapshot
        }
        val networkSnapshot = connectivity?.allNetworks
            ?.asSequence()
            ?.mapNotNull { connectivity?.getNetworkCapabilities(it) }
            ?.firstOrNull {
                it.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) &&
                        !it.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
            }
            ?.wifiSnapshot()
        if (networkSnapshot?.ssid != null) {
            return networkSnapshot
        }
        @Suppress("DEPRECATION")
        return WifiSnapshot(
            wifiManager?.connectionInfo?.ssid?.normalizeSsid(),
            validated = hasValidatedWifiNetwork()
        )
    }

    private fun NetworkCapabilities.wifiSnapshot(): WifiSnapshot {
        val validated = hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return WifiSnapshot(null, validated)
        }
        return WifiSnapshot((transportInfo as? WifiInfo)?.ssid?.normalizeSsid(), validated)
    }

    private fun hasValidatedWifiNetwork(): Boolean {
        return connectivity?.allNetworks
            ?.asSequence()
            ?.mapNotNull { connectivity?.getNetworkCapabilities(it) }
            ?.any {
                it.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) &&
                        !it.hasTransport(NetworkCapabilities.TRANSPORT_VPN) &&
                        it.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
            } == true
    }

    private fun String?.normalizeSsid(): String? {
        return when {
            this == null -> null
            this == WifiManager.UNKNOWN_SSID -> null
            this == "0x" -> null
            isBlank() -> null
            else -> removeSurrounding("\"")
        }
    }

    private fun hasLocationPermission(): Boolean {
        val fineGranted = ContextCompat.checkSelfPermission(
            service,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        if (!fineGranted) {
            return false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val backgroundGranted = ContextCompat.checkSelfPermission(
                service,
                Manifest.permission.ACCESS_BACKGROUND_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
            if (!backgroundGranted && !backgroundPermissionWarningLogged) {
                GlobalState.log("On-demand SSID may be unavailable in background: background location permission missing")
                backgroundPermissionWarningLogged = true
            }
        }
        return true
    }

    private fun setCoreSuspended(next: Boolean) {
        if (suspended == next) {
            return
        }
        suspended = next
        if (service is VpnService) {
            service.setOnDemandSuspended(next)
            return
        }
        invokeCore(if (next) "stopListener" else "startListener")
    }

    private fun invokeCore(method: String) {
        val data = gson.toJson(
            mapOf(
                "id" to "onDemand#${UUID.randomUUID()}",
                "method" to method,
            )
        )
        Core.invokeAction(data) {
            GlobalState.log("On-demand $method result: $it")
        }
    }
}
