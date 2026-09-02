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
  });

  final String tag;
  final Map<String, dynamic> json;
  final bool requiresTor;
}

/// Resolves a user-facing endpoint tag (for example `HKG-02`) into a [TypedConfig].
abstract interface class ConfigSource {
  TypedConfig resolve(String tag);
}

/// Android/Windows platform seam: permissions, airplane mode, TUN fd.
abstract interface class PlatformAdapter {
  Future<bool> isVpnPermissionGranted();
  Future<void> requestVpnPermission();
  Future<bool> isIgnoringBatteryOptimizations();
  Future<void> requestIgnoreBatteryOptimizations();
  Future<bool> isAirplaneMode();
  Future<int?> establish();
  void protect(int fd);
  void closeFd(int fd);
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
  }) {
    _boxSub = box.events.listen(_onBoxEvent);
  }

  final PlatformAdapter platform;
  final ForegroundAdapter foreground;
  final BoxAdapter box;
  final FirewallAdapter firewall;
  final TorAdapter tor;
  final ConfigSource configSource;

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

  Future<void> connect(String tag) async {
    if (_state == TunnelState.connecting || _state == TunnelState.connected) {
      return;
    }
    final epoch = ++_epoch;
    blockReason = null;
    _setState(TunnelState.connecting);

    // grant
    if (!await platform.isVpnPermissionGranted()) {
      await _block(TunnelBlockReason.vpnPermissionDenied);
      return;
    }
    if (epoch != _epoch) {
      return;
    }

    // battery (non-fatal: wizard owns the request UX, Doze risk recorded)
    if (!await platform.isIgnoringBatteryOptimizations()) {
      await platform.requestIgnoreBatteryOptimizations();
    }

    // foreground
    try {
      await foreground.start();
    } on Object {
      await _block(TunnelBlockReason.establishFailed);
      return;
    }

    // airplane
    if (await platform.isAirplaneMode()) {
      await _block(TunnelBlockReason.airplaneMode);
      return;
    }

    TypedConfig config;
    try {
      config = configSource.resolve(tag);
    } on Object {
      await _block(TunnelBlockReason.establishFailed);
      return;
    }

    // tor down → block fallback, sing-box never starts on a dead chain
    if (config.requiresTor && !await tor.isSocksUp()) {
      await _block(TunnelBlockReason.torDown);
      return;
    }

    // establish
    final fd = await platform.establish();
    if (fd == null) {
      await _block(TunnelBlockReason.establishFailed);
      return;
    }
    if (epoch != _epoch) {
      platform.closeFd(fd);
      return;
    }
    _fd = fd;

    // protect
    platform.protect(fd);

    // start
    try {
      await box.start(config);
    } on Object {
      platform.closeFd(fd);
      _fd = null;
      await _block(TunnelBlockReason.boxStartFailed);
      return;
    }

    // firewall — enforced last, only once traffic is already flowing
    try {
      await firewall.enforce();
    } on Object {
      platform.closeFd(fd);
      _fd = null;
      try {
        await box.stop();
      } on Object {
        // engine already gone
      }
      await _block(TunnelBlockReason.boxStartFailed);
      return;
    }
    if (epoch != _epoch) {
      await disconnect();
      return;
    }
    _firewallEnforced = true;
    _setState(TunnelState.connected);
  }

  Future<void> disconnect() async {
    if (_state == TunnelState.disconnected) {
      return;
    }
    _epoch++;
    _setState(TunnelState.disconnecting);
    try {
      await box.stop();
    } on Object {
      await _block(TunnelBlockReason.boxCrashed);
      return;
    }
    final fd = _fd;
    if (fd != null) {
      platform.closeFd(fd);
      _fd = null;
    }
    await foreground.stop();
    if (_firewallEnforced) {
      await firewall.relax();
      _firewallEnforced = false;
    }
    _setState(TunnelState.disconnected);
  }

  Future<void> _block(TunnelBlockReason reason) async {
    blockReason = reason;
    await firewall.enforce();
    _firewallEnforced = true;
    final fd = _fd;
    if (fd != null) {
      platform.closeFd(fd);
      _fd = null;
    }
    _setState(TunnelState.blocked);
  }

  void _onBoxEvent(BoxEvent event) {
    if (event.kind == BoxEventKind.crashed &&
        _state == TunnelState.connected) {
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

  @override
  Future<bool> isVpnPermissionGranted() =>
      _channel
          .invokeMethod<bool>('isVpnPermissionGranted')
          .then((v) => v ?? false)
          .onError((_, _) => false);

  @override
  Future<void> requestVpnPermission() =>
      _channel.invokeMethod<void>('requestVpnPermission');

  @override
  Future<bool> isIgnoringBatteryOptimizations() =>
      _channel
          .invokeMethod<bool>('isIgnoringBatteryOptimizations')
          .then((v) => v ?? false)
          .onError((_, _) => false);

  @override
  Future<void> requestIgnoreBatteryOptimizations() =>
      _channel.invokeMethod<void>('requestIgnoreBatteryOptimizations');

  @override
  Future<bool> isAirplaneMode() =>
      _channel
          .invokeMethod<bool>('isAirplaneMode')
          .then((v) => v ?? true)
          .onError((_, _) => true);

  @override
  Future<int?> establish() =>
      _channel.invokeMethod<int>('establish').then((fd) {
        if (fd == null || fd <= 0) {
          return null;
        }
        return fd;
      }).onError((_, _) => null);

  @override
  void protect(int fd) {
    _channel.invokeMethod<void>('protect', {'fd': fd});
  }

  @override
  void closeFd(int fd) {
    _channel.invokeMethod<void>('closeFd', {'fd': fd});
  }
}
