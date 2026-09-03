import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yourvpn/modules/vpn/repositories/endpoint_store.dart';
import 'package:yourvpn/modules/vpn/repositories/ingestion/endpoint_outbound.dart';
import 'package:yourvpn/modules/vpn/repositories/ingestion/normalized_endpoint.dart';

final String singBoxExe = p.join(
  Directory.current.path,
  'windows',
  'sing-box.exe',
);

bool get singBoxAvailable => File(singBoxExe).existsSync();

NormalizedEndpoint vlessFromUri(String uri) =>
    throw UnsupportedError('use constructors directly in tests');

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yourvpn-endpoints');
  });

  tearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  group('endpointToOutboundJson', () {
    test('vless+reality emits probed shape', () {
      const e = VlessEndpoint(
        tag: 'vless-1',
        address: 'example.com',
        port: 443,
        uuid: 'b831381d-6324-4d53-ad4f-8cda48b30811',
        flow: 'xtls-rprx-vision',
        network: 'tcp',
        security: 'reality',
        sni: 'example.com',
        fingerprint: 'chrome',
        realityPublicKey: 'jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0',
        realityShortId: '0123456789abcdef',
      );
      final json = endpointToOutboundJson(e);

      expect(json['type'], 'vless');
      expect(json['flow'], 'xtls-rprx-vision');
      final tls = json['tls'] as Map<String, dynamic>;
      expect(
        tls['reality']['public_key'],
        'jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0',
      );
      expect((tls['utls'] as Map<String, dynamic>)['fingerprint'], 'chrome');
    });

    test('tuic puts alpn under tls (top-level alpn FATALs the fork)', () {
      const e = TuicEndpoint(
        tag: 'tuic-1',
        address: 'example.com',
        port: 443,
        uuid: 'b831381d-6324-4d53-ad4f-8cda48b30811',
        password: 'pw',
        congestionControl: 'bbr',
      );
      final json = endpointToOutboundJson(e);

      expect(json.containsKey('alpn'), isFalse);
      expect((json['tls'] as Map<String, dynamic>)['alpn'], <String>['h3']);
    });

    test('hysteria2 salamander obfs + h3 alpn', () {
      const e = Hysteria2Endpoint(
        tag: 'hy2-1',
        address: 'example.com',
        port: 443,
        auth: 'pw',
        obfsPassword: 'obfspw',
      );
      final json = endpointToOutboundJson(e);

      final obfs = json['obfs'] as Map<String, dynamic>;
      expect(obfs['type'], 'salamander');
      expect((json['tls'] as Map<String, dynamic>)['alpn'], <String>['h3']);
    });

    test('ss plugin_opts serializes k=v;…', () {
      const e = ShadowsocksEndpoint(
        tag: 'ss-1',
        address: 'example.com',
        port: 8388,
        method: '2022-blake3-aes-128-gcm',
        password: '8JCsPssfgS8tiRwiMlhARg==',
        plugin: 'obfs-local',
        pluginOpts: <String, String>{
          'obfs': 'http',
          'obfs-host': 'example.com',
        },
      );
      final json = endpointToOutboundJson(e);

      expect(json['plugin_opts'], 'obfs=http;obfs-host=example.com');
    });

    test('wg endpoints are rejected (they ship via endpoints[])', () {
      const e = WireGuardEndpoint(
        tag: 'wg',
        privateKey: 'k',
        addresses: <String>[],
        peers: <WireGuardPeer>[],
      );

      expect(() => endpointToOutboundJson(e), throwsArgumentError);
    });
  });

  group('stored shapes pass real sing-box check', () {
    test('all 6 protocols', () {
      if (!singBoxAvailable) {
        return;
      }
      final outbounds = <Map<String, dynamic>>[
        endpointToOutboundJson(
          const VlessEndpoint(
            tag: 'vless-1',
            address: 'example.com',
            port: 443,
            uuid: 'b831381d-6324-4d53-ad4f-8cda48b30811',
            flow: 'xtls-rprx-vision',
            sni: 'example.com',
            fingerprint: 'chrome',
            realityPublicKey: 'jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0',
            realityShortId: '0123456789abcdef',
          ),
        ),
        endpointToOutboundJson(
          const VmessEndpoint(
            tag: 'vmess-1',
            address: 'example.com',
            port: 443,
            uuid: 'b831381d-6324-4d53-ad4f-8cda48b30811',
            security: 'auto',
            tls: 'tls',
            sni: 'example.com',
            network: 'ws',
            wsPath: '/path',
          ),
        ),
        endpointToOutboundJson(
          const ShadowsocksEndpoint(
            tag: 'ss-1',
            address: 'example.com',
            port: 8388,
            method: '2022-blake3-aes-128-gcm',
            password: '8JCsPssfgS8tiRwiMlhARg==',
            plugin: 'obfs-local',
            pluginOpts: <String, String>{
              'obfs': 'http',
              'obfs-host': 'example.com',
            },
          ),
        ),
        endpointToOutboundJson(
          const TrojanEndpoint(
            tag: 'trojan-1',
            address: 'example.com',
            port: 443,
            password: 'pw',
            sni: 'example.com',
            allowInsecure: true,
          ),
        ),
        endpointToOutboundJson(
          const Hysteria2Endpoint(
            tag: 'hy2-1',
            address: 'example.com',
            port: 443,
            auth: 'pw',
            obfsPassword: 'obfspw',
            sni: 'example.com',
          ),
        ),
        endpointToOutboundJson(
          const TuicEndpoint(
            tag: 'tuic-1',
            address: 'example.com',
            port: 443,
            uuid: 'b831381d-6324-4d53-ad4f-8cda48b30811',
            password: 'pw',
            congestionControl: 'bbr',
            sni: 'example.com',
          ),
        ),
      ];
      final file = File('${dir.path}/all-protocols.json');
      file.writeAsStringSync(
        jsonEncode(<String, dynamic>{
          'log': <String, dynamic>{'level': 'info'},
          'outbounds': outbounds,
        }),
      );
      final result = Process.runSync(singBoxExe, <String>[
        'check',
        '-c',
        file.path,
      ]);
      expect(
        result.exitCode,
        0,
        reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
      );
    });
  });

  group('EndpointStore', () {
    test(
      'round-trips stored endpoints via normalized (de)serialization',
      () async {
        final store = EndpointStore(baseDir: dir.path);
        const endpoint = TrojanEndpoint(
          tag: 'trojan-1',
          address: 'example.com',
          port: 443,
          password: 'pw',
          sni: 'example.com',
        );
        await store.save(<StoredEndpoint>[
          const StoredEndpoint(endpoint: endpoint, label: 'Trojan node'),
        ]);

        final read = store.read();

        expect(read, hasLength(1));
        expect(read.single.label, 'Trojan node');
        final restored = read.single.endpoint as TrojanEndpoint;
        expect(restored.address, 'example.com');
        expect(restored.password, 'pw');
        expect(store.tags(), <String>['trojan-1']);
      },
    );

    test('corrupt store → empty list', () {
      final store = EndpointStore(baseDir: dir.path);
      File('${dir.path}/endpoints.json').writeAsStringSync('not json');

      expect(store.read(), isEmpty);
      expect(store.outboundJson(), isEmpty);
    });
  });
}
