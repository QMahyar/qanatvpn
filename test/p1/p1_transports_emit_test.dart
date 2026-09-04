import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yourvpn/modules/vpn/repositories/ingestion/endpoint_outbound.dart';
import 'package:yourvpn/modules/vpn/repositories/ingestion/ingestion_adapter.dart';

/// Engine-probe gate for the cluster-B emitter shapes: every new outbound
/// round-trips through [endpointToOutboundJson] into a full config doc, then
/// the REAL windows/sing-box.exe `check` validates it (parse-only — the
/// engine is never started). Skips cleanly wherever the exe is absent
/// (linux CI, fresh clones). Probe-precedent: test/dns/dns_config_test.dart.
void main() {
  final exe = p.join(Directory.current.path, 'windows', 'sing-box.exe');
  final available = File(exe).existsSync();

  Map<String, dynamic> doc(List<dynamic> outbounds) => <String, dynamic>{
    'log': <String, dynamic>{'level': 'warn'},
    'outbounds': <dynamic>[
      ...outbounds,
      {'type': 'direct', 'tag': 'DIRECT'},
    ],
  };

  Future<void> expectCheckPasses(List<dynamic> outbounds) async {
    if (!available) {
      return;
    }
    final tmp = await Directory.systemTemp.createTemp('emit-probe');
    addTearDown(() => tmp.delete(recursive: true));
    final file = File(p.join(tmp.path, 'probe.json'));
    await file.writeAsString(jsonEncode(doc(outbounds)));
    final result = await Process.run(exe, ['check', '-c', file.path]);
    expect(
      result.exitCode,
      0,
      reason:
          'sing-box check rejected the emitted shape:\n'
          'stderr: ${result.stderr}',
    );
  }

  /// Commit-checked fixture key (build/tmp-probe/ is gitignored, so the
  /// tagged release CI would otherwise find nothing and emit an empty key
  /// that FATALs at connect). A throwaway ed25519 OpenSSH PEM generated for
  /// this fixture, comment 'test-fixture-not-a-secret' — no real credential.
  const String probeEd25519Pem = '''-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACANOQGKG3s2D3gQITMcVL9VHR16vx4O7Az2yNetNG84SwAAAKBs4oJhbOKC
YQAAAAtzc2gtZWQyNTUxOQAAACANOQGKG3s2D3gQITMcVL9VHR16vx4O7Az2yNetNG84Sw
AAAEDNRl1U91slBBifPAM2GhUxn0bvNV0bYXD1kINs/cB4Pw05AYobezYPeBAhMxxUv1Ud
HXq/Hg7sDPbI1600bzhLAAAAGXRlc3QtZml4dHVyZS1ub3QtYS1zZWNyZXQBAgME
-----END OPENSSH PRIVATE KEY-----
''';

  group('SSH outbound', () {
    test('emits user/password/port (password auth)', () async {
      final json = endpointToOutboundJson(
        const SshEndpoint(
          tag: 'ssh-pass',
          address: '203.0.113.10',
          port: 2222,
          user: 'deploy',
          password: 'hunter2',
        ),
      );
      expect(json['type'], 'ssh');
      expect(json['user'], 'deploy');
      expect(json['password'], 'hunter2');
      expect(json['server_port'], 2222);
      expect(json.containsKey('private_key'), isFalse);
      await expectCheckPasses([json]);
    });

    test('emits OpenSSH-PEM key and passes real check', () async {
      final json = endpointToOutboundJson(
        const SshEndpoint(
          tag: 'ssh-key',
          address: '203.0.113.10',
          port: 22,
          privateKey: probeEd25519Pem,
        ),
      );
      expect(json['private_key'], isNotNull);
      await expectCheckPasses([json]);
    });

    test('default root user is not emitted (engine defaults apply)', () {
      final json = endpointToOutboundJson(
        const SshEndpoint(tag: 's', address: 'h', port: 22),
      );
      expect(json.containsKey('user'), isFalse);
    });

    test('host_key list emits when provided', () {
      final json = endpointToOutboundJson(
        const SshEndpoint(
          tag: 's',
          address: 'h',
          port: 22,
          hostKey: ['ssh-ed25519 AAAA test'],
        ),
      );
      expect(json['host_key'], ['ssh-ed25519 AAAA test']);
    });
  });

  group('typed transports on vless', () {
    test('xhttp emits mode + mandatory x_padding_bytes', () async {
      final json = endpointToOutboundJson(
        const VlessEndpoint(
          tag: 'xh',
          address: 'v.example',
          port: 443,
          uuid: 'u',
          transport: TransportOptions(
            type: 'xhttp',
            path: '/x',
            host: 'cdn.example',
            mode: 'stream-up',
          ),
        ),
      );
      final transport = json['transport'] as Map<String, dynamic>;
      expect(transport['type'], 'xhttp');
      expect(transport['mode'], 'stream-up');
      // Fork struct has NO omitempty on x_padding_bytes; absence FATALs.
      expect(transport['x_padding_bytes'], '100-1000');
      await expectCheckPasses([json]);
    });

    test('xhttp strips a host header (fork FATALs on it)', () {
      final json = endpointToOutboundJson(
        const VlessEndpoint(
          tag: 'xh',
          address: 'v.example',
          port: 443,
          uuid: 'u',
          transport: TransportOptions(
            type: 'xhttp',
            headers: {'Host': 'evil', 'X-Custom': '1'},
          ),
        ),
      );
      final headers =
          (json['transport'] as Map<String, dynamic>)['headers']
              as Map<String, dynamic>;
      expect(headers.containsKey('Host'), isFalse);
      expect(headers.containsKey('host'), isFalse);
      expect(headers['X-Custom'], '1');
    });

    test('grpc emits service_name + timeouts', () async {
      final json = endpointToOutboundJson(
        const VlessEndpoint(
          tag: 'g',
          address: 'v.example',
          port: 443,
          uuid: 'u',
          transport: TransportOptions(
            type: 'grpc',
            serviceName: 'svc',
            idleTimeoutSeconds: 60,
            pingTimeoutSeconds: 15,
          ),
        ),
      );
      final transport = json['transport'] as Map<String, dynamic>;
      expect(transport['service_name'], 'svc');
      expect(transport['idle_timeout'], '60s');
      expect(transport['ping_timeout'], '15s');
      await expectCheckPasses([json]);
    });

    test('httpupgrade emits path + host', () async {
      final json = endpointToOutboundJson(
        const VlessEndpoint(
          tag: 'hu',
          address: 'v.example',
          port: 443,
          uuid: 'u',
          transport: TransportOptions(
            type: 'httpupgrade',
            path: '/up',
            host: 'cdn.example',
          ),
        ),
      );
      final transport = json['transport'] as Map<String, dynamic>;
      expect(transport['host'], 'cdn.example');
      expect(transport['path'], '/up');
      await expectCheckPasses([json]);
    });

    test('http transport emits host as 1-element array', () async {
      final json = endpointToOutboundJson(
        const VlessEndpoint(
          tag: 'h1',
          address: 'v.example',
          port: 80,
          uuid: 'u',
          transport: TransportOptions(
            type: 'http',
            path: '/p',
            host: 'front.example',
            method: 'PUT',
          ),
        ),
      );
      final transport = json['transport'] as Map<String, dynamic>;
      expect(transport['host'], ['front.example']);
      expect(transport['method'], 'PUT');
      await expectCheckPasses([json]);
    });

    test('ws via typed transport emits path + headers', () async {
      final json = endpointToOutboundJson(
        const VlessEndpoint(
          tag: 'w',
          address: 'v.example',
          port: 443,
          uuid: 'u',
          transport: TransportOptions(
            type: 'ws',
            path: '/ws',
            headers: {'X-Foo': 'bar'},
          ),
        ),
      );
      final transport = json['transport'] as Map<String, dynamic>;
      expect(transport['type'], 'ws');
      expect(transport['path'], '/ws');
      await expectCheckPasses([json]);
    });

    test('legacy flat wsPath still emits (URI import path)', () async {
      final json = endpointToOutboundJson(
        const VlessEndpoint(
          tag: 'w2',
          address: 'v.example',
          port: 443,
          uuid: 'u',
          network: 'ws',
          wsPath: '/legacy',
          wsHost: 'front.example',
        ),
      );
      final transport = json['transport'] as Map<String, dynamic>;
      expect(transport['path'], '/legacy');
      expect((transport['headers'] as Map)['Host'], 'front.example');
      await expectCheckPasses([json]);
    });

    test('no transport → no transport key (never null-valued)', () {
      final json = endpointToOutboundJson(
        const VlessEndpoint(
          tag: 'plain',
          address: 'v.example',
          port: 443,
          uuid: 'u',
        ),
      );
      expect(json.containsKey('transport'), isFalse);
    });
  });

  group('ECH', () {
    test('ech enabled without config emits ech.enabled', () async {
      final json = endpointToOutboundJson(
        const VlessEndpoint(
          tag: 'ech',
          address: 'v.example',
          port: 443,
          uuid: 'u',
          echEnabled: true,
        ),
      );
      final ech =
          (json['tls'] as Map<String, dynamic>)['ech'] as Map<String, dynamic>;
      expect(ech['enabled'], isTrue);
      expect(ech.containsKey('config'), isFalse);
      await expectCheckPasses([json]);
    });

    test('ech with PEM config emits config array', () {
      final json = endpointToOutboundJson(
        const VlessEndpoint(
          tag: 'ech2',
          address: 'v.example',
          port: 443,
          uuid: 'u',
          echEnabled: true,
          echConfig:
              '-----BEGIN ECH CONFIGS-----\nAAA=\n-----END ECH CONFIGS-----',
        ),
      );
      final ech =
          (json['tls'] as Map<String, dynamic>)['ech'] as Map<String, dynamic>;
      expect(ech['config'], isA<List<dynamic>>());
    });
  });

  group('ssh import', () {
    test('ssh:// URI parses user/password/host/port', () {
      final adapter = IngestionAdapter();
      final endpoints = adapter.parseShareLines([
        'ssh://deploy:hunter2@203.0.113.10:2222#my-server',
      ]);
      final e = endpoints.single;
      expect(e, isA<SshEndpoint>());
      final ssh = e as SshEndpoint;
      expect(ssh.user, 'deploy');
      expect(ssh.password, 'hunter2');
      expect(ssh.address, '203.0.113.10');
      expect(ssh.port, 2222);
      expect(ssh.tag, 'my-server');
    });

    test('sing-box json ssh outbound parses (private_key list joined)', () {
      final adapter = IngestionAdapter();
      final endpoints = adapter.parseAndNormalize(
        RawSubscription(
          bytes: utf8.encode(
            jsonEncode(<String, dynamic>{
              'outbounds': <dynamic>[
                <String, dynamic>{
                  'type': 'ssh',
                  'tag': 'srv',
                  'server': '10.0.0.1',
                  'server_port': 22,
                  'user': 'root',
                  'private_key': <String>['line1', 'line2'],
                },
              ],
            }),
          ),
          url: Uri.parse('https://sub.example/singbox.json'),
        ),
      );
      final ssh = endpoints.single as SshEndpoint;
      expect(ssh.privateKey, 'line1\nline2');
    });

    test('sing-box json vmess+grpc round-trips service_name', () {
      final adapter = IngestionAdapter();
      final endpoints = adapter.parseAndNormalize(
        RawSubscription(
          bytes: utf8.encode(
            jsonEncode(<String, dynamic>{
              'outbounds': <dynamic>[
                <String, dynamic>{
                  'type': 'vmess',
                  'tag': 'g',
                  'server': 'v.example',
                  'server_port': 443,
                  'uuid': 'u',
                  'security': 'auto',
                  'transport': <String, dynamic>{
                    'type': 'grpc',
                    'service_name': 'tls-svc',
                  },
                },
              ],
            }),
          ),
          url: Uri.parse('https://sub.example/singbox.json'),
        ),
      );
      final vmess = endpoints.single as VmessEndpoint;
      expect(vmess.transport?.type, 'grpc');
      expect(vmess.transport?.serviceName, 'tls-svc');
      // And re-emit keeps it:
      final out = endpointToOutboundJson(vmess);
      expect(
        (out['transport'] as Map<String, dynamic>)['service_name'],
        'tls-svc',
      );
    });

    test(
      'unknown-kind store round-trip: SshEndpoint persists + rehydrates',
      () {
        const original = SshEndpoint(
          tag: 'k',
          address: 'h',
          port: 22,
          privateKey: 'PEM',
        );
        final json = normalizedToJson(original);
        expect(json['kind'], 'SshEndpoint');
        final back = normalizedFromJson(json);
        expect(back, isA<SshEndpoint>());
        expect((back as SshEndpoint).privateKey, 'PEM');
      },
    );
  });
}
