package com.yourvpn.yourvpn

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.net.VpnService
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Handlers for the Dart `vpn_service` MethodChannel (safe defaults live on
/// the Dart side in [MethodChannelPlatformAdapter]; this side implements the
/// real platform calls).
object VpnServiceBridge {

    const val CHANNEL = "vpn_service"

    private const val VPN_REQUEST_CODE = 41

    fun configure(flutterEngine: FlutterEngine, activity: Activity) {
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        )
        // Engine lifecycle events flow Kotlin→Dart on a dedicated channel;
        // MethodChannelBoxAdapter subscribes for crashed/stopped events.
        val eventChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "box_events",
        )
        BoxEngine.setEventSink { kind, message ->
            eventChannel.invokeMethod(
                "onEngineEvent",
                mapOf("kind" to kind, if (message != null) "message" to message else "message" to null),
            )
        }
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isVpnPermissionGranted" -> result.success(isVpnPrepared(activity))
                "requestVpnPermission" -> {
                    val intent = VpnService.prepare(activity)
                    if (intent == null) {
                        result.success(true)
                    } else {
                        pendingVpnResult = result
                        activity.startActivityForResult(intent, VPN_REQUEST_CODE)
                    }
                }
                "isIgnoringBatteryOptimizations" ->
                    result.success(BatteryOptHelper.isIgnoringBatteryOptimizations(activity))
                "requestIgnoreBatteryOptimizations" -> {
                    BatteryOptHelper.requestIgnoreBatteryOptimizations(activity)
                    result.success(null)
                }
                "isAirplaneMode" -> result.success(isAirplaneMode(activity))
                "boxStart" -> {
                    val config = call.argument<String>("config")
                    if (config.isNullOrEmpty()) {
                        result.error("invalid_args", "config is required", null)
                    } else {
                        BoxEngine.boxStart(
                            activity.applicationContext,
                            config,
                            call.argument<List<String>>("includePackages") ?: emptyList(),
                            call.argument<List<String>>("excludePackages") ?: emptyList(),
                            result,
                        )
                    }
                }
                "boxStop" -> BoxEngine.boxStop(activity.applicationContext, result)
                "listInstalledApps" -> {
                    result.success(listInstalledApps(activity))
                }
                "installUpdate" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrEmpty()) {
                        result.error("invalid_args", "url is required", null)
                    } else {
                        try {
                            activity.startActivity(
                                Intent(Intent.ACTION_VIEW, Uri.parse(url)),
                            )
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("install_failed", e.message, null)
                        }
                    }
                }
                "startForeground" -> {
                    ForegroundService.start(activity)
                    result.success(null)
                }
                "stopForeground" -> {
                    ForegroundService.stop(activity)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun handleActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != VPN_REQUEST_CODE) {
            return false
        }
        val result = pendingVpnResult
        pendingVpnResult = null
        result?.success(resultCode == Activity.RESULT_OK)
        return true
    }

    private var pendingVpnResult: MethodChannel.Result? = null

    private fun isVpnPrepared(context: Context): Boolean =
        VpnService.prepare(context) == null

    private fun isAirplaneMode(context: Context): Boolean {
        return Settings.Global.getInt(
            context.contentResolver,
            Settings.Global.AIRPLANE_MODE_ON,
            0,
        ) != 0
    }

    /// User-installed launchable apps for the wizard's per-app picker.
    /// System packages and this app are excluded — splitting yourself
    /// through the tunnel is always a footgun.
    private fun listInstalledApps(activity: Activity): List<Map<String, String>> {
        val packages = activity.packageManager
            .getInstalledPackages(PackageManager.GET_META_DATA)
        return packages.mapNotNull { info ->
            val name = info.packageName ?: return@mapNotNull null
            if (info.applicationInfo == null) return@mapNotNull null
            if ((info.applicationInfo!!.flags and ApplicationInfo.FLAG_SYSTEM) != 0) {
                return@mapNotNull null
            }
            if (name == activity.packageName) return@mapNotNull null
            val label = try {
                info.applicationInfo!!.loadLabel(activity.packageManager).toString()
            } catch (e: Exception) {
                name
            }
            mapOf("packageName" to name, "label" to label)
        }
    }
}
