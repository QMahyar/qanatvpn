import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/tunnel.dart';
import '../../onboarding/wizard.dart';

/// UI-facing VPN state. Mirrors [TunnelState] plus the connected tag.
class VpnState {
  const VpnState(this.phase, this.tag, this.blockReason);

  factory VpnState.disconnected() =>
      const VpnState(TunnelState.disconnected, null, null);
  factory VpnState.connecting() =>
      const VpnState(TunnelState.connecting, null, null);
  factory VpnState.connected(String tag) =>
      VpnState(TunnelState.connected, tag, null);
  factory VpnState.disconnecting() =>
      const VpnState(TunnelState.disconnecting, null, null);
  factory VpnState.blocked(TunnelBlockReason reason) =>
      VpnState(TunnelState.blocked, null, reason);

  final TunnelState phase;
  final String? tag;
  final TunnelBlockReason? blockReason;

  @override
  bool operator ==(Object other) =>
      other is VpnState &&
      other.phase == phase &&
      other.tag == tag &&
      other.blockReason == blockReason;

  @override
  int get hashCode => Object.hash(phase, tag, blockReason);
}

/// Provides the app's [Tunnel]. Overridden in tests with fakes.
final tunnelProvider = Provider<Tunnel>((ref) {
  throw UnimplementedError('override with real adapters in main.dart');
});

final foregroundAdapterProvider = Provider<ForegroundAdapter>((ref) {
  throw UnimplementedError('override with real adapters in main.dart');
});

final boxAdapterProvider = Provider<BoxAdapter>((ref) {
  throw UnimplementedError('override with real adapters in main.dart');
});

final firewallAdapterProvider = Provider<FirewallAdapter>((ref) {
  throw UnimplementedError('override with real adapters in main.dart');
});

final torAdapterProvider = Provider<TorAdapter>((ref) {
  throw UnimplementedError('override with real adapters in main.dart');
});

final configSourceProvider = Provider<ConfigSource>((ref) {
  throw UnimplementedError('override with real adapters in main.dart');
});

/// Assembles the [Tunnel] from the overridden adapters.
final tunnelAssemblyProvider = Provider<Tunnel>((ref) {
  return Tunnel(
    platform: ref.watch(platformAdapterProvider),
    foreground: ref.watch(foregroundAdapterProvider),
    box: ref.watch(boxAdapterProvider),
    firewall: ref.watch(firewallAdapterProvider),
    tor: ref.watch(torAdapterProvider),
    configSource: ref.watch(configSourceProvider),
  );
});

/// Single source of VPN truth for the UI.
///
/// Calls the deep seam with a tag (`Tunnel.connect("HKG-02")`), never a JSON
/// string; JSON assembly lives behind [ConfigSource] inside the tunnel.
class VpnNotifier extends Notifier<VpnState> {
  @override
  VpnState build() {
    final tunnel = ref.watch(tunnelProvider);
    _sub?.cancel();
    _sub = tunnel.status.listen((state) {
      this.state = switch (state) {
        TunnelState.disconnected => VpnState.disconnected(),
        TunnelState.connecting => VpnState.connecting(),
        TunnelState.connected => VpnState.connected(_lastTag ?? ''),
        TunnelState.disconnecting => VpnState.disconnecting(),
        TunnelState.reconnecting => VpnState.connecting(),
        TunnelState.blocked => VpnState.blocked(
          tunnel.blockReason ?? TunnelBlockReason.establishFailed,
        ),
      };
    });
    return VpnState.disconnected();
  }

  StreamSubscription<TunnelState>? _sub;
  String? _lastTag;

  Future<void> connect(String tag) async {
    _lastTag = tag;
    await ref.read(tunnelProvider).connect(tag);
  }

  Future<void> disconnect() async {
    await ref.read(tunnelProvider).disconnect();
  }
}

final vpnNotifierProvider = NotifierProvider<VpnNotifier, VpnState>(
  VpnNotifier.new,
);
