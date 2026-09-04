import 'dart:async';

import 'package:flutter/services.dart';

/// Lifecycle states of the VPN tunnel.
enum TunnelState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  reconnecting,
  blocked,
}

/// Why the tunnel ended up in [TunnelState.blocked].
enum TunnelBlockReason {
  vpnPermissionDenied,
  establishFailed,
  airplaneMode,
  torDown,
  boxStartFailed,
  boxCrashed,
}

/// Configuration handed to [BoxAdapter], already resolved for [Tunnel.connect]'s tag.
/// Callers never see the JSON.
class TypedConfig {
  const TypedConfig({
    required this.tag,
    required this.json,
    this.requiresTor = false,
    this.includePackages = const <String>[],
    this.excludePackages = const <String>[],
  });

  final String tag;
  final Map<String, dynamic> json;
  final bool requiresTor;

  /// Per-app split from the wizard: allowlist goes to include (only these
  /// apps tunnel), bypass list goes to exclude. Never both non-empty.
  final List<String> includePackages;
  final List<String> excludePackages;
}

/// One installed application (per-app split picker row).
class InstalledApp {
  const InstalledApp({required this.packageName, required this.label});

  final String packageName;
  final String label;
}

/// Resolves a user-facing endpoint tag (for example `HKG-02`) into a [TypedConfig].
abstract interface class ConfigSource {
  Future<TypedConfig> resolve(String tag);
}

/// Android/Windows platform seam: permissions, airplane mode, TUN fd.
abstract interface class PlatformAdapter {
  Future<bool> isVpnPermissionGranted();
  Future<void> requestVpnPermission();
  Future<bool> isIgnoringBatteryOptimizations();
  Future<void> requestIgnoreBatteryOptimizations();
  Future<bool> isAirplaneMode();

  /// True when the engine opens the TUN itself (libbox 1.14 calls
  /// `PlatformInterface.openTun` from Go during box start, so establish and
  /// protect happen inside [BoxAdapter.start], not here).
  bool get engineManagedTun;

  Future<int?> establish();
  void protect(int fd);
  void closeFd(int fd);

  /// Installed user apps for the per-app split picker. Unimplemented on
  /// platforms without a package manager.
  Future<List<InstalledApp>> listInstalledApps();
}

/// Foreground service (notification) keeping the process alive on Android.
abstract interface class ForegroundAdapter {
  Future<void> start();
  Future<void> stop();
}

/// sing-box engine (Android: libbox in-process, Windows: sing-box.exe subprocess).
abstract interface class BoxAdapter {
  Future<void> start(TypedConfig config);
  Future<void> stop();
  Stream<BoxEvent> get events;
}

enum BoxEventKind { started, stopped, crashed }

class BoxEvent {
  const BoxEvent(this.kind, [this.error]);

  final BoxEventKind kind;
  final Object? error;
}

/// Max firewall (WFP/iptables): block everything except the tunnel.
abstract interface class FirewallAdapter {
  Future<void> enforce();
  Future<void> relax();
}

/// Tor SOCKS sidecar on 127.0.0.1:9050. Never `type: tor` inside sing-box
/// (entry blocked would FATAL the whole box, upstream #4200).
abstract interface class TorAdapter {
  Future<bool> isSocksUp();
}

/// Per-step ceilings for the connect/disconnect control path.
///
/// A hung platform call, store read, or engine start must surface as
/// `blocked` (fail closed), never strand the UI in `connecting` forever.
/// Tests inject tiny values to assert the timeout paths without waiting.
class TunnelTimeouts {
  const TunnelTimeouts({
    this.foregroundStart = const Duration(seconds: 8),
    this.resolve = const Duration(seconds: 15),
    this.boxStart = const Duration(seconds: 30),
    this.firewallEnforce = const Duration(seconds: 8),
    this.boxStop = const Duration(seconds: 10),
  });

  final Duration foregroundStart;
  final Duration resolve;
  final Duration boxStart;
  final Duration firewallEnforce;
  final Duration boxStop;
}

/// Per-phase timings for one `connect()` run, oldest phase first.
///
/// Recorded with a monotonic Stopwatch inside [Tunnel.connect] and exposed
/// via [Tunnel.lastConnectMetrics] for the diagnostics screen. Timings are
/// best-effort (a phase that throws still records its elapsed) and never
/// affect control flow.
class ConnectMetrics {
  ConnectMetrics({required this.tag, required this.phases});

  final String tag;

  /// Phase name → elapsed wall time, in run order.
  final Map<String, Duration> phases;

  /// Sum of all recorded phases.
  Duration get total => phases.values.fold(Duration.zero, (a, b) => a + b);

  /// One-line summary for logs: `tag total=1.2s box=0.9s config=0.2s …`.
  @override
  String toString() {
    final parts = <String>[
      for (final e in phases.entries) '${e.key}=${e.value.inMilliseconds}ms',
    ];
    return '$tag total=${total.inMilliseconds}ms ${parts.join(' ')}';
  }
}

/// Deep module owning the Dart↔Kotlin↔Go VPN seam.
///
/// One call runs the whole guarded sequence
/// `grant → battery → foreground → establish → protect → start → firewall`
/// and falls back to firewall-enforced `blocked` on every failure path, so no
/// caller can skip a step and leak.
class Tunnel {
  Tunnel({
    required this.platform,
    required this.foreground,
    required this.box,
    required this.firewall,
    required this.tor,
    required this.configSource,
    this.timeouts = const TunnelTimeouts(),
  }) {
    _boxSub = box.events.listen(_onBoxEvent);
  }

  final PlatformAdapter platform;
  final ForegroundAdapter foreground;
  final BoxAdapter box;
  final FirewallAdapter firewall;
  final TorAdapter tor;
  final ConfigSource configSource;
  final TunnelTimeouts timeouts;

  late final StreamSubscription<BoxEvent> _boxSub;
  int? _fd;
  bool _firewallEnforced = false;

  /// Generation counter: invalidated by connect/disconnect so stale
  /// in-flight sequences abort instead of racing the newer one.
  int _epoch = 0;

  final StreamController<TunnelState> _status =
      StreamController<TunnelState>.broadcast();

  TunnelState _state = TunnelState.disconnected;

  /// Last reason the tunnel went blocked, null when not blocked.
  TunnelBlockReason? blockReason;

  TunnelState get state => _state;

  Stream<TunnelState> get status => _status.stream;

  /// Timings for the most recent `connect()` attempt (success or blocked).
  /// Null before the first connect. The Diagnostics screen reads this to
  /// show where slow connects spend their time.
  ConnectMetrics? lastConnectMetrics;

  /// Abort the sequence when a newer connect/disconnect invalidated [epoch].
  /// Returns true when the caller must stop immediately.
  bool _stale(int epoch) => epoch != _epoch;

  /// Time [phase] and record it into [phases]. The phase records even when
  /// [work] throws, so slow-then-failing steps still show their cost.
  static Future<T> _timed<T>(
    Map<String, Duration> phases,
    String phase,
    Future<T> Function() work,
  ) async {
    final sw = Stopwatch()..start();
    try {
      return await work();
    } finally {
      sw.stop();
      phases[phase] = sw.elapsed;
    }
  }

  Future<void> connect(String tag) async {
    if (_state == TunnelState.connecting || _state == TunnelState.connected) {
      return;
    }
    final epoch = ++_epoch;
    blockReason = null;
    _setState(TunnelState.connecting);
    final phases = <String, Duration>{};
    // Publish exactly once per attempt, on every exit path below.
    void publishMetrics() {
      lastConnectMetrics = ConnectMetrics(tag: tag, phases: Map.of(phases));
    }

    // grant
    try {
      final granted = await _timed(
        phases,
        'grant',
        platform.isVpnPermissionGranted,
      );
      if (!granted) {
        publishMetrics();
        await _block(TunnelBlockReason.vpnPermissionDenied);
        return;
      }
    } on Object {
      publishMetrics();
      await _block(TunnelBlockReason.establishFailed);
      return;
    }
    if (_stale(epoch)) {
      publishMetrics();
      return;
    }

    // battery (non-fatal: wizard owns the request UX, Doze risk recorded)
    try {
      await _timed(phases, 'battery', () async {
        if (!await platform.isIgnoringBatteryOptimizations()) {
          await platform.requestIgnoreBatteryOptimizations();
        }
      });
    } on Object {
      // A failing battery API must not strand connect; the wizard owns UX.
    }
    if (_stale(epoch)) {
      publishMetrics();
      return;
    }

    // airplane (before foreground: no notification/service when offline)
    try {
      final airplane = await _timed(
        phases,
        'airplane',
        platform.isAirplaneMode,
      );
      if (airplane) {
        publishMetrics();
        await _block(TunnelBlockReason.airplaneMode);
        return;
      }
    } on Object {
      if (_stale(epoch)) {
        publishMetrics();
        return;
      }
      publishMetrics();
      await _block(TunnelBlockReason.establishFailed);
      return;
    }
    if (_stale(epoch)) {
      publishMetrics();
      return;
    }

    // foreground
    try {
      await _timed(
        phases,
        'foreground',
        () => foreground.start().timeout(timeouts.foregroundStart),
      );
    } on Object {
      if (_stale(epoch)) {
        publishMetrics();
        return;
      }
      publishMetrics();
      await _block(TunnelBlockReason.establishFailed);
      return;
    }
    if (_stale(epoch)) {
      publishMetrics();
      return;
    }

    TypedConfig config;
    try {
      config = await _timed(
        phases,
        'config',
        () => configSource.resolve(tag).timeout(timeouts.resolve),
      );
    } on Object {
      if (_stale(epoch)) {
        publishMetrics();
        return;
      }
      publishMetrics();
      await _block(TunnelBlockReason.establishFailed);
      return;
    }
    if (_stale(epoch)) {
      publishMetrics();
      return;
    }

    // tor down → block fallback, sing-box never starts on a dead chain
    try {
      final torDown = await _timed(phases, 'tor', () async {
        return config.requiresTor && !await tor.isSocksUp();
      });
      if (torDown) {
        publishMetrics();
        await _block(TunnelBlockReason.torDown);
        return;
      }
    } on Object {
      if (_stale(epoch)) {
        publishMetrics();
        return;
      }
      publishMetrics();
      await _block(TunnelBlockReason.torDown);
      return;
    }
    if (_stale(epoch)) {
      publishMetrics();
      return;
    }

    // establish — engine-managed platforms (libbox 1.14) open the TUN from
    // Go via openTun while box.start runs; fd never crosses to Dart.
    final int? fd;
    if (platform.engineManagedTun) {
      fd = null;
    } else {
      try {
        fd = await _timed(phases, 'establish', platform.establish);
      } on Object {
        if (_stale(epoch)) {
          publishMetrics();
          return;
        }
        publishMetrics();
        await _block(TunnelBlockReason.establishFailed);
        return;
      }
      if (fd == null) {
        publishMetrics();
        await _block(TunnelBlockReason.establishFailed);
        return;
      }
      if (_stale(epoch)) {
        platform.closeFd(fd);
        publishMetrics();
        return;
      }
      _fd = fd;

      // protect
      try {
        final protectFd = fd;
        await _timed(phases, 'protect', () async {
          platform.protect(protectFd);
        });
      } on Object {
        platform.closeFd(fd);
        _fd = null;
        if (_stale(epoch)) {
          publishMetrics();
          return;
        }
        publishMetrics();
        await _block(TunnelBlockReason.establishFailed);
        return;
      }
    }

    // start
    try {
      await _timed(
        phases,
        'box',
        () => box.start(config).timeout(timeouts.boxStart),
      );
    } on Object {
      if (fd != null) {
        platform.closeFd(fd);
        _fd = null;
      }
      if (_stale(epoch)) {
        publishMetrics();
        return;
      }
      publishMetrics();
      await _block(TunnelBlockReason.boxStartFailed);
      return;
    }
    if (_state == TunnelState.blocked) {
      // A crash event owned the outcome while box.start was in flight.
      // Stop the half-started engine but keep blocked so the UI shows why
      // instead of flipping to disconnected.
      if (fd != null) {
        platform.closeFd(fd);
        _fd = null;
      }
      try {
        await box.stop().timeout(timeouts.boxStop);
      } on Object {
        // engine already gone
      }
      publishMetrics();
      return;
    }
    if (_stale(epoch)) {
      // A newer disconnect won the race while box.start was in flight.
      // Stop what we just started instead of announcing connected on a
      // tunnel the UI no longer wants.
      if (fd != null) {
        platform.closeFd(fd);
        _fd = null;
      }
      try {
        await box.stop().timeout(timeouts.boxStop);
      } on Object {
        // engine already gone
      }
      publishMetrics();
      await disconnect();
      return;
    }

    // firewall — enforced last, only once traffic is already flowing
    try {
      await _timed(
        phases,
        'firewall',
        () => firewall.enforce().timeout(timeouts.firewallEnforce),
      );
    } on Object {
      if (fd != null) {
        platform.closeFd(fd);
        _fd = null;
      }
      try {
        await box.stop().timeout(timeouts.boxStop);
      } on Object {
        // engine already gone
      }
      if (_stale(epoch)) {
        publishMetrics();
        return;
      }
      publishMetrics();
      await _block(TunnelBlockReason.boxStartFailed);
      return;
    }
    if (_stale(epoch)) {
      publishMetrics();
      await disconnect();
      return;
    }
    _firewallEnforced = true;
    // A crash event that arrived while box.start/firewall were in flight
    // already moved us to blocked via _onBoxEvent; do not resurrect.
    if (_state == TunnelState.blocked) {
      publishMetrics();
      return;
    }
    publishMetrics();
    _setState(TunnelState.connected);
  }

  Future<void> disconnect() async {
    if (_state == TunnelState.disconnected) {
      return;
    }
    _epoch++;
    _setState(TunnelState.disconnecting);
    try {
      await box.stop().timeout(timeouts.boxStop);
    } on Object {
      await _block(TunnelBlockReason.boxCrashed);
      return;
    }
    final fd = _fd;
    if (fd != null) {
      platform.closeFd(fd);
      _fd = null;
    }
    try {
      await foreground.stop();
    } on Object {
      // Foreground teardown is best-effort; the tunnel is already down.
    }
    if (_firewallEnforced) {
      try {
        await firewall.relax();
      } on Object {
        // A failing relax must not resurrect the tunnel; stay disconnected
        // and let the next connect re-enforce.
      }
      _firewallEnforced = false;
    }
    _setState(TunnelState.disconnected);
  }

  Future<void> _block(TunnelBlockReason reason) async {
    blockReason = reason;
    try {
      await firewall.enforce().timeout(timeouts.firewallEnforce);
    } on Object {
      // The block state itself must never hang: a wedged firewall still
      // leaves the tunnel blocked (fail closed), just without the flag that
      // would relax it later.
    }
    _firewallEnforced = true;
    final fd = _fd;
    if (fd != null) {
      platform.closeFd(fd);
      _fd = null;
    }
    // No stale "active" UX: a blocked tunnel owns no foreground service.
    // Best-effort: the block state stands even if teardown throws.
    try {
      await foreground.stop().timeout(timeouts.foregroundStart);
    } on Object {
      // Already stopped or wedged; stay blocked regardless.
    }
    _setState(TunnelState.blocked);
  }

  void _onBoxEvent(BoxEvent event) {
    if (event.kind != BoxEventKind.crashed) {
      return;
    }
    if (_state == TunnelState.connected) {
      _block(TunnelBlockReason.boxCrashed);
      return;
    }
    // A FATAL between box.start and connected (log-watcher `crashed`
    // arriving while still connecting) must not leave the UI on a dead
    // engine. Bump the generation synchronously so the in-flight connect's
    // post-await stale checks abort instead of announcing connected; the
    // async _block below owns the final state.
    if (_state == TunnelState.connecting) {
      _epoch++;
      _block(TunnelBlockReason.boxCrashed);
    }
  }

  void _setState(TunnelState next) {
    _state = next;
    _status.add(next);
  }

  Future<void> dispose() async {
    await _boxSub.cancel();
    await _status.close();
  }
}

/// Real Android/Windows adapters, wired over the `vpn_service` MethodChannel.
///
/// The Kotlin handlers arrive with the platform todo; until then every method
/// reports the safe default (not granted, airplane on) so no caller can skip
/// the guard sequence.
class MethodChannelPlatformAdapter implements PlatformAdapter {
  static const _channel = MethodChannel('vpn_service');

  List<InstalledApp>? _appsCache;

  /// Clears the memoized [listInstalledApps] result (wizard refresh, tests).
  void invalidateAppsCache() {
    _appsCache = null;
  }

  @override
  Future<bool> isVpnPermissionGranted() => _channel
      .invokeMethod<bool>('isVpnPermissionGranted')
      .then((v) => v ?? false)
      .onError((_, _) => false);

  @override
  Future<void> requestVpnPermission() =>
      _channel.invokeMethod<void>('requestVpnPermission');

  @override
  Future<bool> isIgnoringBatteryOptimizations() => _channel
      .invokeMethod<bool>('isIgnoringBatteryOptimizations')
      .then((v) => v ?? false)
      .onError((_, _) => false);

  @override
  Future<void> requestIgnoreBatteryOptimizations() =>
      _channel.invokeMethod<void>('requestIgnoreBatteryOptimizations');

  @override
  Future<bool> isAirplaneMode() => _channel
      .invokeMethod<bool>('isAirplaneMode')
      .then((v) => v ?? true)
      .onError((_, _) => true);

  @override
  bool get engineManagedTun => true;

  @override
  Future<int?> establish() => _channel
      .invokeMethod<int>('establish')
      .then((fd) {
        if (fd == null || fd <= 0) {
          return null;
        }
        return fd;
      })
      .onError((_, _) => null);

  @override
  void protect(int fd) {
    _channel.invokeMethod<void>('protect', {'fd': fd});
  }

  @override
  void closeFd(int fd) {
    _channel.invokeMethod<void>('closeFd', {'fd': fd});
  }

  @override
  Future<List<InstalledApp>> listInstalledApps() async {
    final cached = _appsCache;
    if (cached != null) {
      return cached;
    }
    try {
      final raw = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'listInstalledApps',
      );
      if (raw == null) {
        return const <InstalledApp>[];
      }
      final apps = <InstalledApp>[
        for (final item in raw)
          InstalledApp(
            packageName: item['packageName'] as String? ?? '',
            label: item['label'] as String? ?? '',
          ),
      ].where((app) => app.packageName.isNotEmpty).toList();
      _appsCache = apps;
      return apps;
    } on Object {
      return const <InstalledApp>[];
    }
  }
}
