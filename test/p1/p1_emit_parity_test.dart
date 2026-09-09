import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qanatvpn/modules/vpn/repositories/ingestion/endpoint_outbound.dart';
import 'package:qanatvpn/modules/vpn/repositories/ingestion/ingestion_adapter.dart';

RawSubscription raw(String source) => RawSubscription(
  bytes: utf8.encode(source),
  url: Uri.parse('https://sub.example.test/feed'),
);

final String singBoxExe = p.join(
  Directory.current.path,
  'windows',
  'sing-box.exe',
);
bool get singBoxAvailable => File(singBoxExe).existsSync();

/// Minimal runnable config wrapping one outbound for `sing-box check`.
Map<String, dynamic> wrapOutbound(Map<String, dynamic> outbound) => {
  'log': {'level': 'error'},
  'outbounds': [
    outbound,
    {'type': 'direct', 'tag': 'DIRECT'},
  ],
  'route': {'final': 'DIRECT', 'auto_detect_interface': true},
};

Future<void> checkOutbound(Map<String, dynamic> outbound) async {
  if (!singBoxAvailable) {
    // CI: no windows/sing-box.exe on Linux. Throwing from an async helper
    // reports FAILURE, not skip (probe 34306459219) — return silently; the
    // calling tests carry test-level skip: so this path only runs when the
    // helper's caller did not gate.
    return;
  }
  final dir = await Directory.systemTemp.createTemp('p1emit');
  try {
    final file = File('${dir.path}/cfg.json');
    await file.writeAsString(jsonEncode(wrapOutbound(outbound)));
    final result = await Process.run(singBoxExe, ['check', '-c', file.path]);
    expect(
      result.exitCode,
      0,
      reason: 'sing-box check failed: ${result.stderr}${result.stdout}',
    );
  } finally {
    await dir.delete(recursive: true);
  }
}

void main() {
  group('P1 emit parity', () {
    test('Clash AWG keeps S3/S4/I1-I5/id/ip/ib', () {
      const yaml = '''
proxies:
  - name: awg-full
    type: wireguard
    server: 203.0.113.10
    port: 51820
    private-key: eCbtX5g5Pof3zH0Gu6dzulIzLB0B5xj+OhIfgVtWu1A=
    ip: 10.7.0.2/32
    peers:
      - server: 203.0.113.10
        port: 51820
        public-key: abc=
    amnezia-wg-option:
      jc: 5
      jmin: 30
      jmax: 1000
      s1: 56
      s2: 152
      s3: 1
      s4: 2
      h1: "11"
      h2: "22"
      h3: "33"
      h4: "44"
      i1: "aaa"
      i2: "bbb"
      i3: "ccc"
      i4: "ddd"
      i5: "eee"
      id: "quic"
      ip: "1.1.1.1"
      ib: "x"
''';
      final endpoints = ClashYamlParser().parse(yaml);
      final wg = endpoints.single as WireGuardEndpoint;
      expect(wg.awg?.s3, 1);
      expect(wg.awg?.s4, 2);
      expect(wg.awg?.i1, 'aaa');
      expect(wg.awg?.i5, 'eee');
      expect(wg.awg?.id, 'quic');
      expect(wg.awg?.ip, '1.1.1.1');
      expect(wg.awg?.ib, 'x');
    });

    test('Hysteria2 mport/hop emitted + passes sing-box check',
      skip: singBoxAvailable ? false : 'needs windows/sing-box.exe', () async {
      final endpoints = IngestionAdapter().parseAndNormalize(
        raw(
          'hysteria2://secret@example.com:443?mport=20000-30000&sni=example.com#HY',
        ),
      );
      final e = endpoints.single as Hysteria2Endpoint;
      expect(e.ports, '20000-30000');
      final json = endpointToOutboundJson(e);
      // Dash form normalized to the fork's min:max range syntax.
      expect(json['server_ports'], <String>['20000:30000']);
      await checkOutbound(json);
    });

    test('Hysteria2 hop_interval seconds emitted', () {
      const e = Hysteria2Endpoint(
        tag: 'hy',
        address: 'h.example.com',
        port: 443,
        auth: 'a',
        ports: '20000-20010',
        hopIntervalSeconds: 30,
      );
      final json = endpointToOutboundJson(e);
      expect(json['hop_interval'], '30s');
    });

    test('TUIC udp_relay_mode emitted + passes sing-box check',
      skip: singBoxAvailable ? false : 'needs windows/sing-box.exe', () async {
      const uuid = 'b831381d-6324-4d53-ad4f-8cda48b30811';
      final endpoints = IngestionAdapter().parseAndNormalize(
        raw(
          'tuic://$uuid:p@example.com:443?congestion_control=bbr&udp_relay_mode=native#TU',
        ),
      );
      final e = endpoints.single as TuicEndpoint;
      expect(e.udpRelayMode, 'native');
      final json = endpointToOutboundJson(e);
      expect(json['udp_relay_mode'], 'native');
      await checkOutbound(json);
    });

    test('reality without fp defaults to chrome (no FATAL)',
      skip: singBoxAvailable ? false : 'needs windows/sing-box.exe', () async {
      const e = VlessEndpoint(
        tag: 'r',
        address: 'example.com',
        port: 443,
        uuid: 'b831381d-6324-4d53-ad4f-8cda48b30811',
        realityPublicKey: 'SbVKOEMjK0sIlbwg4akyBg5mL5KZwwB-ed4eEE7YnRc',
        realityShortId: '6ba85179',
      );
      final json = endpointToOutboundJson(e);
      final tls = json['tls'] as Map<String, dynamic>;
      expect((tls['utls'] as Map)['fingerprint'], 'chrome');
      expect(tls['reality'], isNotNull);
      await checkOutbound(json);
    });

    test(
      'malformed Clash hy2/tuic throws FormatException (no TypeError DoS)',
      () {
        const badHy2 = '''
proxies:
  - name: bad
    type: hysteria2
    server: 1.2.3.4
    port: notaport
''';
        expect(
          () => ClashYamlParser().parse(badHy2),
          throwsA(isA<FormatException>()),
        );
        const badTuic = '''
proxies:
  - name: bad
    type: tuic
    server: 1.2.3.4
    port: 443
    uuid: u
''';
        // missing port type is fine here; bad server type triggers FormatException
        const badTuic2 = '''
proxies:
  - name: bad
    type: tuic
    server: 12345
    port: 443
    uuid: u
''';
        expect(
          () => ClashYamlParser().parse(badTuic2),
          throwsA(isA<FormatException>()),
        );
        expect(() => ClashYamlParser().parse(badTuic), returnsNormally);
      },
    );
  });
}
