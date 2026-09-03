package com.yourvpn.yourvpn

import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log
import com.yourvpn.libbox.TunOptions

/// The real VpnService owning the TUN. No VPN logic lives here: libbox calls
/// PlatformInterfaceWrapper.openTun() with the config's tun options and we
/// establish the interface; protect() is exposed for the Go engine's sockets.
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
        // The engine opens the TUN itself via openTun(); service start is only
        // needed so INSTANCE is available and the process holds the VPN grant.
        return START_NOT_STICKY
    }

    val openFds = mutableMapOf<Int, ParcelFileDescriptor>()

    companion object {
        private const val TAG = "YourVpnService"

        @Volatile
        var INSTANCE: YourVpnService? = null
            private set

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
