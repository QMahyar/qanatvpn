package com.yourvpn.yourvpn

import android.app.Activity
import android.content.Context
import android.content.Intent
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
                "establish" -> {
                    val prepare = VpnService.prepare(activity)
                    if (prepare != null) {
                        result.error(
                            "vpn_permission_required",
                            "VpnService.prepare() returned an intent; grant consent first",
                            null,
                        )
                    } else {
                        startEstablish(activity, result)
                    }
                }
                "protect" -> {
                    val fd = call.argument<Int>("fd") ?: -1
                    val ok = YourVpnService.INSTANCE?.protect(fd) ?: false
                    result.success(ok)
                }
                "closeFd" -> {
                    val fd = call.argument<Int>("fd") ?: -1
                    result.success(YourVpnService.closeFd(fd))
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

    private fun startEstablish(activity: Activity, result: MethodChannel.Result) {
        YourVpnService.pushEstablishCallback(result)
        val intent = Intent(activity, YourVpnService::class.java)
        activity.startService(intent)
    }
}
