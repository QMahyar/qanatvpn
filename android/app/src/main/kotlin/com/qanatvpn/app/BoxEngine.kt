package com.qanatvpn.app

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.util.Log
import com.qanatvpn.libbox.CommandClient
import com.qanatvpn.libbox.CommandClientHandler
import com.qanatvpn.libbox.CommandClientOptions
import com.qanatvpn.libbox.CommandServer
import com.qanatvpn.libbox.CommandServerHandler
import com.qanatvpn.libbox.ConnectionEvents
import com.qanatvpn.libbox.ConnectionOwner
import com.qanatvpn.libbox.InterfaceUpdateListener
import com.qanatvpn.libbox.Libbox
import com.qanatvpn.libbox.LogIterator
import com.qanatvpn.libbox.NetworkInterface
import com.qanatvpn.libbox.NetworkInterfaceIterator
import com.qanatvpn.libbox.OutboundGroupItemIterator
import com.qanatvpn.libbox.OutboundGroupIterator
import com.qanatvpn.libbox.OverrideOptions
import com.qanatvpn.libbox.SetupOptions
import com.qanatvpn.libbox.StatusMessage
import com.qanatvpn.libbox.StringIterator
import com.qanatvpn.libbox.SystemProxyStatus
import com.qanatvpn.libbox.TunOptions
import io.flutter.plugin.common.MethodChannel
import java.net.NetworkInterface as JavaNetworkInterface
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/// Owns the Go engine lifecycle: libbox setup, CommandServer, and the
/// platform callbacks Go makes during start (openTun, protect).
///
/// Dart's `vpn_service` channel reaches this via boxStart/boxStop. All engine
/// work runs on one background thread; channel results are posted back to the
/// main thread (MethodChannel.Result is not thread-safe).
object BoxEngine {
    private const val TAG = "BoxEngine"
    private const val SERVICE_WAIT_MS = 3000L

    private var initialized = false
    private var commandServer: CommandServer? = null
    private var platformWrapper: PlatformInterfaceWrapper? = null
    private var logWatcher: CommandClient? = null
    private var engineRunning = false

    /// Kotlin→Dart engine events: kind = started | stopped | crashed.
    /// Wired from VpnServiceBridge (needs the binary messenger).
    private var eventSink: ((String, String?) -> Unit)? = null

    fun setEventSink(sink: (String, String?) -> Unit) {
        eventSink = sink
    }

    private fun emitEvent(kind: String, message: String? = null) {
        mainHandler.post { eventSink?.invoke(kind, message) }
    }

    private val executor: ExecutorService =
        Executors.newSingleThreadExecutor { r -> Thread(r, "box-engine") }
    private val mainHandler = Handler(Looper.getMainLooper())

    fun boxStart(
        context: Context,
        configJson: String,
        includePackages: List<String>,
        excludePackages: List<String>,
        result: MethodChannel.Result,
    ) {
        executor.execute {
            try {
                ensureSetup(context.applicationContext)
                ensureVpnServiceRunning(context.applicationContext)
                val server = commandServer
                    ?: throw IllegalStateException("command server not initialized")
                val overrides = OverrideOptions().apply {
                    autoRedirect = false
                    if (includePackages.isNotEmpty()) {
                        includePackage = StringListIterator(includePackages)
                    }
                    if (excludePackages.isNotEmpty()) {
                        excludePackage = StringListIterator(excludePackages)
                    }
                }
                server.startOrReloadService(configJson, overrides)
                engineRunning = true
                attachLogWatcher()
                emitEvent("started")
                mainHandler.post { result.success(null) }
            } catch (e: Throwable) {
                Log.e(TAG, "box start failed", e)
                mainHandler.post { result.error("box_start_failed", e.message, null) }
            }
        }
    }

    fun boxStop(context: Context, result: MethodChannel.Result) {
        executor.execute {
            engineRunning = false
            detachLogWatcher()
            try {
                commandServer?.closeService()
            } catch (e: Throwable) {
                Log.w(TAG, "closeService failed", e)
            } finally {
                platformWrapper?.closeTun()
            }
            emitEvent("stopped")
            mainHandler.post { result.success(null) }
        }
    }

    /// Crash detection + live logs over the log stream: the exported
    /// CommandClient has no service-status subscription, but instance FATALs
    /// reach `WriteLogs`; every line is forwarded to the Dart Logs screen.
    /// Also treats a dropped command stream while running as a crash (the
    /// whole Go runtime died). Start-time FATALs do NOT arrive here — they
    /// surface synchronously through startOrReloadService's error.
    private fun attachLogWatcher() {
        if (logWatcher != null) return
        try {
            val handler = object : CommandClientHandler {
                override fun writeLogs(messageList: LogIterator?) {
                    if (messageList == null) return
                    while (messageList.hasNext()) {
                        val entry = messageList.next() ?: continue
                        val message = entry.message ?: continue
                        if (message.isEmpty()) continue
                        // Every line feeds the Logs screen.
                        emitEvent("log", message)
                        if (!engineRunning) continue
                        if (message.contains("FATAL")) {
                            Log.e(TAG, "engine fatal: $message")
                            emitEvent("crashed", message)
                            engineRunning = false
                            return
                        }
                    }
                }

                override fun disconnected(message: String?) {
                    if (engineRunning) {
                        Log.e(TAG, "engine command stream dropped: $message")
                        emitEvent("crashed", message)
                        engineRunning = false
                    }
                }

                override fun connected() {}
                override fun clearLogs() {}
                override fun setDefaultLogLevel(level: Int) {}
                override fun initializeClashMode(
                    modeList: StringIterator?,
                    currentMode: String?,
                ) {}

                override fun updateClashMode(newMode: String?) {}
                override fun writeConnectionEvents(events: ConnectionEvents?) {}
                override fun writeGroups(message: OutboundGroupIterator?) {}
                override fun writeOutbounds(message: OutboundGroupItemIterator?) {}
                override fun writeStatus(message: StatusMessage?) {}
            }
            val options = CommandClientOptions()
            options.addCommand(Libbox.CommandLog)
            val client = Libbox.newCommandClient(handler, options)
            client.connect()
            logWatcher = client
            Log.i(TAG, "log watcher attached")
        } catch (e: Throwable) {
            Log.w(TAG, "log watcher attach failed (crash events disabled)", e)
        }
    }

    private fun detachLogWatcher() {
        val client = logWatcher ?: return
        logWatcher = null
        try {
            client.disconnect()
        } catch (e: Throwable) {
            Log.w(TAG, "log watcher detach failed", e)
        }
    }

    @Synchronized
    private fun ensureSetup(context: Context) {
        if (initialized) return
        val filesDir = context.filesDir
        val options = SetupOptions().apply {
            basePath = filesDir.absolutePath
            workingPath = filesDir.resolve("working").absolutePath
            tempPath = filesDir.resolve("temp").absolutePath
            fixAndroidStack = true
            commandServerListenPort = 0
            commandServerSecret = ""
            logMaxLines = 300
            debug = false
            crashReportSource = "client"
        }
        Libbox.setup(options)
        val wrapper = PlatformInterfaceWrapper(context)
        platformWrapper = wrapper
        val server = Libbox.newCommandServer(CommandServerHandlerImpl(), wrapper)
        server.start()
        commandServer = server
        initialized = true
        Log.i(TAG, "libbox command server started (engine ${Libbox.version()})")
    }

    private fun ensureVpnServiceRunning(context: Context) {
        if (QanatVpnService.INSTANCE != null) return
        context.startService(Intent(context, QanatVpnService::class.java))
        val deadline = System.currentTimeMillis() + SERVICE_WAIT_MS
        while (QanatVpnService.INSTANCE == null && System.currentTimeMillis() < deadline) {
            Thread.sleep(50)
        }
        if (QanatVpnService.INSTANCE == null) {
            throw IllegalStateException("VpnService did not start")
        }
    }
}

/// The libbox PlatformInterface Go calls back into: TUN creation from the
/// config's tun options, socket protection, default interface monitoring.
class PlatformInterfaceWrapper(context: Context) : com.qanatvpn.libbox.PlatformInterface {
    private val TAG = "BoxEngine.Platform"
    private val appContext = context.applicationContext

    private var tunPfd: ParcelFileDescriptor? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    override fun localDNSTransport(): com.qanatvpn.libbox.LocalDNSTransport? = null

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    override fun autoDetectInterfaceControl(fd: Int) {
        val service = QanatVpnService.INSTANCE
            ?: throw Exception("VpnService is not running")
        if (!service.protect(fd)) {
            throw Exception("protect(fd=$fd) failed")
        }
    }

    override fun openTun(options: TunOptions): Int {
        val service = QanatVpnService.INSTANCE
            ?: throw Exception("VpnService is not running")
        val builder = service.Builder()
        builder.setSession(SESSION)
        builder.setMtu(options.getMTU())
        builder.setBlocking(false)

        var firstInet4 = ""
        val inet4 = options.getInet4Address()
        while (inet4.hasNext()) {
            val prefix = inet4.next()
            if (firstInet4.isEmpty()) firstInet4 = prefix.address()
            builder.addAddress(prefix.address(), prefix.prefix())
        }
        var firstInet6 = ""
        val inet6 = options.getInet6Address()
        while (inet6.hasNext()) {
            val prefix = inet6.next()
            if (firstInet6.isEmpty()) firstInet6 = prefix.address()
            builder.addAddress(prefix.address(), prefix.prefix())
        }

        var dns = ""
        val dnsIterator = options.getDNSServerAddress()
        while (dnsIterator.hasNext()) {
            val next = dnsIterator.next()
            if (dns.isEmpty()) dns = next
        }
        if (dns.isEmpty()) {
            dns = firstInet4.ifEmpty { firstInet6 }
        }
        if (dns.isEmpty()) {
            throw Exception("no tun address available for dns server")
        }
        builder.addDnsServer(dns)

        if (options.getAutoRoute()) {
            val route4 = options.getInet4RouteAddress()
            if (route4.hasNext()) {
                while (route4.hasNext()) {
                    val prefix = route4.next()
                    builder.addRoute(prefix.address(), prefix.prefix())
                }
            } else {
                builder.addRoute("0.0.0.0", 0)
            }
            val route6 = options.getInet6RouteAddress()
            if (route6.hasNext()) {
                while (route6.hasNext()) {
                    val prefix = route6.next()
                    builder.addRoute(prefix.address(), prefix.prefix())
                }
            } else {
                builder.addRoute("::", 0)
            }
        }

        val include = options.getIncludePackage()
        while (include.hasNext()) {
            builder.addAllowedApplication(include.next())
        }
        val exclude = options.getExcludePackage()
        while (exclude.hasNext()) {
            builder.addDisallowedApplication(exclude.next())
        }

        builder.setConfigureIntent(
            PendingIntent.getActivity(
                appContext,
                0,
                Intent(appContext, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE,
            ),
        )

        val pfd = builder.establish()
            ?: throw Exception("VpnService.Builder.establish() returned null")
        closeTun()
        tunPfd = pfd
        Log.i(TAG, "tun established fd=${pfd.fd} mtu=${options.getMTU()}")
        return pfd.fd
    }

    fun closeTun() {
        val pfd = tunPfd ?: return
        tunPfd = null
        try {
            pfd.close()
        } catch (e: Exception) {
            Log.w(TAG, "close tun fd failed", e)
        }
    }

    override fun useProcFS(): Boolean = true

    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String?,
        sourcePort: Int,
        destinationAddress: String?,
        destinationPort: Int,
    ): ConnectionOwner = throw Exception("unsupported")

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {
        if (listener == null) return
        val connectivity = connectivityManager() ?: return
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                pushDefaultInterface(listener)
            }

            override fun onLinkPropertiesChanged(
                network: Network,
                linkProperties: LinkProperties,
            ) {
                pushDefaultInterface(listener)
            }
        }
        networkCallback = callback
        try {
            connectivity.registerDefaultNetworkCallback(callback)
        } catch (e: Exception) {
            Log.w(TAG, "register network callback failed", e)
        }
        pushDefaultInterface(listener)
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {
        val callback = networkCallback ?: return
        networkCallback = null
        val connectivity = connectivityManager() ?: return
        try {
            connectivity.unregisterNetworkCallback(callback)
        } catch (e: Exception) {
            Log.w(TAG, "unregister network callback failed", e)
        }
    }

    private fun pushDefaultInterface(listener: InterfaceUpdateListener) {
        val connectivity = connectivityManager() ?: return
        val network = connectivity.activeNetwork ?: return
        val capabilities = connectivity.getNetworkCapabilities(network) ?: return
        if (!capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
            return
        }
        val properties = connectivity.getLinkProperties(network) ?: return
        val name = properties.interfaceName ?: return
        val index = try {
            JavaNetworkInterface.getByName(name)?.index ?: 0
        } catch (e: Exception) {
            0
        }
        val isExpensive =
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
        listener.updateDefaultInterface(name, index, isExpensive, false)
    }

    override fun getInterfaces(): NetworkInterfaceIterator {
        val out = mutableListOf<NetworkInterface>()
        val interfaces = JavaNetworkInterface.getNetworkInterfaces()
        while (interfaces != null && interfaces.hasMoreElements()) {
            val it = interfaces.nextElement()
            val item = NetworkInterface()
            item.index = it.index
            item.mtu = it.mtu
            item.name = it.name
            item.addresses = StringListIterator(
                it.interfaceAddresses.mapNotNull { a -> a.address?.hostAddress },
            )
            item.flags = 0
            item.type = when {
                it.name.startsWith("wlan") -> com.qanatvpn.libbox.Libbox.InterfaceTypeWIFI
                it.name.startsWith("rmnet") ||
                    it.name.startsWith("ccmni") ||
                    it.name.startsWith("mobile") -> com.qanatvpn.libbox.Libbox.InterfaceTypeCellular
                else -> com.qanatvpn.libbox.Libbox.InterfaceTypeOther
            }
            item.dnsServer = StringListIterator(emptyList())
            item.gateway = StringListIterator(emptyList())
            out.add(item)
        }
        return NetworkInterfaceListIterator(out)
    }

    private fun connectivityManager(): ConnectivityManager? =
        appContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager

    override fun underNetworkExtension(): Boolean = false

    override fun includeAllNetworks(): Boolean = false

    override fun readWIFIState(): com.qanatvpn.libbox.WIFIState? = null

    override fun clearDNSCache() {}

    override fun sendNotification(notification: com.qanatvpn.libbox.Notification?) {}

    override fun cancelNotification(identifier: String?, typeID: Int) {}

    override fun startNeighborMonitor(listener: com.qanatvpn.libbox.NeighborUpdateListener?) {}

    override fun closeNeighborMonitor(listener: com.qanatvpn.libbox.NeighborUpdateListener?) {}

    override fun registerMyInterface(name: String?) {}

    override fun usePlatformShell(): Boolean = false

    override fun checkPlatformShell() {}

    override fun openShellSession(
        user: com.qanatvpn.libbox.PlatformUser?,
        command: String?,
        environ: StringIterator?,
        term: String?,
        rows: Int,
        cols: Int,
    ): com.qanatvpn.libbox.ShellSession = throw Exception("unsupported")

    override fun lookupUser(username: String?): com.qanatvpn.libbox.PlatformUser =
        throw Exception("unsupported")

    override fun lookupSFTPServer(): String = throw Exception("unsupported")

    override fun readSystemSSHHostKey(): String = ""

    override fun tailscaleHostname(): String = ""

    override fun usePlatformBridge(): Boolean = false

    override fun createBridge(
        options: com.qanatvpn.libbox.BridgeOptions?,
    ): com.qanatvpn.libbox.BridgeSession = throw Exception("unsupported")

    private companion object {
        private const val SESSION = "QANATVPN"
    }
}

/// Handler Go invokes for stop/reload/proxy requests. The command client is
/// not wired yet, so most of these are inert for now.
class CommandServerHandlerImpl : CommandServerHandler {
    override fun serviceStop() {
        Log.i(TAG, "engine requested service stop")
    }

    override fun serviceReload() {}

    override fun getSystemProxyStatus(): SystemProxyStatus =
        SystemProxyStatus().apply {
            enabled = false
            available = false
        }

    override fun setSystemProxyEnabled(enabled: Boolean) {}

    override fun triggerNativeCrash() = throw Exception("disabled")

    override fun writeDebugMessage(message: String) {
        Log.d(TAG, message)
    }

    override fun connectSSHAgent() = throw Exception("unsupported")

    private companion object {
        private const val TAG = "BoxEngine.Handler"
    }
}

private class StringListIterator(
    private val items: List<String>,
) : StringIterator {
    private var index = 0

    override fun hasNext(): Boolean = index < items.size

    override fun next(): String = items[index++]

    override fun len(): Int = items.size
}

private class NetworkInterfaceListIterator(
    private val items: List<NetworkInterface>,
) : NetworkInterfaceIterator {
    private var index = 0

    override fun hasNext(): Boolean = index < items.size

    override fun next(): NetworkInterface = items[index++]
}
