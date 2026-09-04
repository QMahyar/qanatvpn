import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/core/services/tunnel.dart';
import 'package:yourvpn/modules/vpn/logic/vpn_notifier.dart';

class _StubTunnel implements Tunnel {
  final StreamController<TunnelState> _status =
      StreamController<TunnelState>.broadcast();

  final List<String> calls = <String>[];

  @override
  TunnelBlockReason? blockReason;

  TunnelState _state = TunnelState.disconnected;

  @override
  TunnelState get state => _state;

  @override
  Stream<TunnelState> get status => _status.stream;

  @override
  PlatformAdapter get platform => throw UnimplementedError();

  @override
  ForegroundAdapter get foreground => throw UnimplementedError();

  @override
  BoxAdapter get box => throw UnimplementedError();

  @override
  FirewallAdapter get firewall => throw UnimplementedError();

  @override
  TorAdapter get tor => throw UnimplementedError();

  @override
  ConfigSource get configSource => throw UnimplementedError();

  @override
  TunnelTimeouts get timeouts => const TunnelTimeouts();

  @override
  ConnectMetrics? lastConnectMetrics;

  void finishConnect(String tag) {
    _state = TunnelState.connected;
    _status.add(TunnelState.connected);
  }

  @override
  Future<void> connect(String tag) async {
    calls.add('connect:$tag');
    _state = TunnelState.connecting;
    _status.add(TunnelState.connecting);
  }

  @override
  Future<void> disconnect() async {
    calls.add('disconnect');
    _state = TunnelState.disconnecting;
    _status.add(TunnelState.disconnecting);
    _state = TunnelState.disconnected;
    _status.add(TunnelState.disconnected);
  }

  @override
  Future<void> dispose() async {
    await _status.close();
  }
}

void main() {
  test(
    'VpnNotifier.connect passes the tag straight to Tunnel.connect',
    () async {
      final tunnel = _StubTunnel();
      final container = ProviderContainer(
        overrides: [tunnelProvider.overrideWithValue(tunnel)],
      );
      addTearDown(container.dispose);

      final seen = <VpnState>[];
      final sub = container.listen(
        vpnNotifierProvider,
        (_, VpnState next) => seen.add(next),
      );
      addTearDown(sub.close);

      await container.read(vpnNotifierProvider.notifier).connect('HKG-02');
      tunnel.finishConnect('HKG-02');
      await Future<void>.delayed(Duration.zero);

      expect(tunnel.calls, <String>['connect:HKG-02']);
      expect(
        seen.any((s) => s.phase == TunnelState.connected && s.tag == 'HKG-02'),
        isTrue,
      );
      expect(seen.any((s) => s.phase == TunnelState.connecting), isTrue);
    },
  );

  test('VpnNotifier.disconnect reaches Tunnel.disconnect', () async {
    final tunnel = _StubTunnel();
    final container = ProviderContainer(
      overrides: [tunnelProvider.overrideWithValue(tunnel)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(vpnNotifierProvider.notifier);
    container.read(vpnNotifierProvider);

    await notifier.disconnect();
    await Future<void>.delayed(Duration.zero);

    expect(tunnel.calls, contains('disconnect'));
  });
}
