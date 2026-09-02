package com.yourvpn.yourvpn

import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log

/// The real VpnService owning the TUN. No VPN logic lives here: it only
/// establishes the interface from parameters sent by the Dart side and
/// exposes protect() for the Go engine's sockets.
class YourVpnService : VpnService() {

    override fun onCreate() {
        super.onCreate()
        INSTANCE = this
    }

    override fun onDestroy() {
        INSTANCE = null
        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val fd = establishFromParams()
        val callback = popEstablishCallback()
        if (callback != null) {
            if (fd == null) {
                callback.error("establish_failed", "VpnService.Builder.establish() returned null", null)
            } else {
                callback.success(fd)
            }
        }
        return START_NOT_STICKY
    }

    private fun establishFromParams(): Int? {
        return try {
            val builder = Builder()
                .setSession(SESSION)
                .setMtu(1408)
                .addAddress("172.19.0.1", 30)
                .addAddress("fdfe:dcba:9876::1", 126)
                .addDnsServer("172.19.0.1")
                .addRoute("0.0.0.0", 0)
                .addRoute("::", 0)
                .setBlocking(false)
            val pending = PendingIntent.getActivity(
                this,
                0,
                Intent(this, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE,
            )
            builder.setConfigureIntent(pending)
            builder.establish()?.let { pfd ->
                val fd = pfd.fd
                openFds[fd] = pfd
                fd
            }
        } catch (e: Exception) {
            Log.e(TAG, "establish failed", e)
            null
        }
    }

    private val openFds = mutableMapOf<Int, ParcelFileDescriptor>()

    companion object {
        private const val TAG = "YourVpnService"
        private const val SESSION = "YOURVPN"

        @Volatile
        var INSTANCE: YourVpnService? = null
            private set

        private var establishCallback: io.flutter.plugin.common.MethodChannel.Result? = null

        fun pushEstablishCallback(callback: io.flutter.plugin.common.MethodChannel.Result) {
            establishCallback = callback
        }

        fun popEstablishCallback(): io.flutter.plugin.common.MethodChannel.Result? {
            val cb = establishCallback
            establishCallback = null
            return cb
        }

        fun closeFd(fd: Int): Boolean {
            val pfd = INSTANCE?.openFds?.remove(fd) ?: return false
            try {
                pfd.close()
            } catch (e: Exception) {
                Log.w(TAG, "close fd $fd failed", e)
            }
            return true
        }
    }
}
