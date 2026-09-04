import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/modules/routing/latency.dart';
import 'package:yourvpn/modules/vpn/repositories/endpoints_controller.dart'
    show endpointStoreProvider;
import 'package:yourvpn/modules/vpn/repositories/endpoint_store.dart';
import 'package:yourvpn/modules/vpn/repositories/ingestion/normalized_endpoint.dart';

class _FakePinger implements LatencyPinger {
  final Map<String, int?> byHost;
  _FakePinger(this.byHost);

  @override
  Future<int?> ping(String host, int port) async => byHost[host];
}

StoredEndpoint _stored(NormalizedEndpoint endpoint) =>
    StoredEndpoint(endpoint: endpoint, label: 'l');

void main() {
  group('endpointProbeTarget', () {
    test('vless carries address/port directly', () {
      final target = endpointProbeTarget(
        _stored(
          const VlessEndpoint(
            tag: 'hk',
            uuid: 'u',
            address: '1.2.3.4',
            port: 443,
          ),
        ),
      );
      expect(target, (address: '1.2.3.4', port: 443));
    });

    test('wg peer endpoint host:port parses', () {
      final target = endpointProbeTarget(
        _stored(
          const WireGuardEndpoint(
            tag: 'awg',
            privateKey: 'k',
            addresses: ['10.0.0.2/32'],
            peers: [
              WireGuardPeer(
                publicKey: 'p',
                endpoint: '5.6.7.8:51820',
                allowedIps: ['0.0.0.0/0'],
              ),
            ],
          ),
        ),
      );
      expect(target, (address: '5.6.7.8', port: 51820));
    });

    test('wg bracketed IPv6 peer endpoint parses', () {
      final target = endpointProbeTarget(
        _stored(
          const WireGuardEndpoint(
            tag: 'awg6',
            privateKey: 'k',
            addresses: ['fd00::2/128'],
            peers: [
              WireGuardPeer(
                publicKey: 'p',
                endpoint: '[2001:db8::1]:51820',
                allowedIps: ['::/0'],
              ),
            ],
          ),
        ),
      );
      expect(target, (address: '2001:db8::1', port: 51820));
    });
  });

  group('bestTag', () {
    test('lowest non-null wins', () {
      const report = LatencyState(
        samples: {'a': 220, 'b': 80, 'c': null, 'd': 400},
      );
      expect(report.bestTag(), 'b');
    });

    test('all unreachable → null', () {
      const report = LatencyState(samples: {'a': null});
      expect(report.bestTag(), isNull);
    });
  });

  group('LatencyController', () {
    test('sweep samples via pinger and exposes best', () async {
      final container = ProviderContainer(overrides: [
        endpointStoreProvider.overrideWithValue(EndpointStore(baseDir: _dir())),
      ]);
      addTearDown(container.dispose);
      final store = container.read(endpointStoreProvider);
      await store.save(<StoredEndpoint>[
        _stored(
          const VlessEndpoint(
            tag: 'hk',
            uuid: 'u',
            address: 'hk.example',
            port: 443,
          ),
        ),
        _stored(
          const VlessEndpoint(
            tag: 'us',
            uuid: 'u',
            address: 'us.example',
            port: 443,
          ),
        ),
      ]);

      final state = await container
          .read(latencyProvider.notifier)
          .refresh(pinger: _FakePinger({'hk.example': 30, 'us.example': 90}));

      expect(state.samples['hk'], 30);
      expect(state.samples['us'], 90);
      expect(state.bestTag(), 'hk');
    });

    test('unreachable host samples null and never throws', () async {
      final container = ProviderContainer(overrides: [
        endpointStoreProvider.overrideWithValue(EndpointStore(baseDir: _dir())),
      ]);
      addTearDown(container.dispose);
      final store = container.read(endpointStoreProvider);
      await store.save(<StoredEndpoint>[
        _stored(
          const VlessEndpoint(
            tag: 'dead',
            uuid: 'u',
            address: 'dead.example',
            port: 443,
          ),
        ),
      ]);

      final state = await container
          .read(latencyProvider.notifier)
          .refresh(pinger: _FakePinger(const {}));

      expect(state.samples['dead'], isNull);
    });
  });
}

String _dir() {
  final dir = Directory.systemTemp.createTempSync('latency-test');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir.path;
}
