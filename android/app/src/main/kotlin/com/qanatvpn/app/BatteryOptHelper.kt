package com.qanatvpn.app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings

/// Battery exemption helper. VPN apps are acceptable users of
/// ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS per Google Play policy; Doze
/// would otherwise kill the foreground service mid-tunnel.
object BatteryOptHelper {

    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return power.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun requestIgnoreBatteryOptimizations(context: Context) {
        if (isIgnoringBatteryOptimizations(context)) {
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return
        }
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:${context.packageName}")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }
}
