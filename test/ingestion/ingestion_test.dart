import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qanatvpn/modules/vpn/repositories/ingestion/ingestion_adapter.dart';

RawSubscription raw(String source, {Uri? url}) => RawSubscription(
  bytes: utf8.encode(source),
  url: url ?? Uri.parse('https://sub.example.test/feed'),
);

void main() {
  late IngestionAdapter adapter;

  setUp(() => adapter = IngestionAdapter());

  group('share links', () {
    test('vless:// with reality params → VlessEndpoint', () {
      final endpoints = adapter.parseAndNormalize(
        raw(
          'vless://b831381d-6324-4d53-ad4f-8cda48b30811@example.com:443?'
          'type=tcp&security=reality&flow=xtls-rprx-vision&fp=chrome&'
          'pbk=SbVKOEMjK0sIlbwg4akyBg5mL5KZwwB-ed4eEE7YnRc&sid=6ba85179#HK-Reality',
        ),
      );

      expect(endpoints, hasLength(1));
      final e = endpoints.first as VlessEndpoint;
      expect(e.tag, 'HK-Reality');
      expect(e.uuid, 'b831381d-6324-4d53-ad4f-8cda48b30811');
      expect(e.address, 'example.com');
      expect(e.port, 443);
      expect(e.flow, 'xtls-rprx-vision');
      expect(e.security, 'reality');
      expect(e.realityPublicKey, 'SbVKOEMjK0sIlbwg4akyBg5mL5KZwwB-ed4eEE7YnRc');
      expect(e.realityShortId, '6ba85179');
      expect(e.fingerprint, 'chrome');
    });

    test('vmess:// base64 json → VmessEndpoint', () {
      final payload = base64Url.encode(
        utf8.encode(
          jsonEncode(<String, dynamic>{
            'v': '2',
            'ps': 'JP-01',
            'add': 'jp.example.com',
            'port': '8443',
            'id': 'b831381d-6324-4d53-ad4f-8cda48b30811',
            'aid': '0',
            'net': 'ws',
            'scy': 'auto',
            'tls': 'tls',
            'sni': 'cdn.example.com',
            'path': '/ws',
          }),
        ),
      );
      final endpoints = adapter.parseAndNormalize(raw('vmess://$payload'));

      final e = endpoints.single as VmessEndpoint;
      expect(e.tag, 'JP-01');
      expect(e.address, 'jp.example.com');
      expect(e.port, 8443);
      expect(e.security, 'auto');
      expect(e.network, 'ws');
      expect(e.tls, 'tls');
      expect(e.wsPath, '/ws');
    });

    test('ss:// userinfo-base64 → ShadowsocksEndpoint', () {
      final userinfo = base64Url.encode(utf8.encode('aes-256-gcm:secret123'));
      final endpoints = adapter.parseAndNormalize(
        raw('ss://$userinfo@1.2.3.4:8388#SS-Node'),
      );

      final e = endpoints.single as ShadowsocksEndpoint;
      expect(e.tag, 'SS-Node');
      expect(e.method, 'aes-256-gcm');
      expect(e.password, 'secret123');
      expect(e.address, '1.2.3.4');
      expect(e.port, 8388);
    });

    test('ss:// whole-link-base64 form → ShadowsocksEndpoint', () {
      final whole = base64Url.encode(
        utf8.encode('chacha20-ietf-poly1305:pw@5.6.7.8:443'),
      );
      final endpoints = adapter.parseAndNormalize(raw('ss://$whole#Free'));

      final e = endpoints.single as ShadowsocksEndpoint;
      expect(e.method, 'chacha20-ietf-poly1305');
      expect(e.password, 'pw');
      expect(e.address, '5.6.7.8');
      expect(e.tag, 'Free');
    });

    test('trojan:// → TrojanEndpoint', () {
      final endpoints = adapter.parseAndNormalize(
        raw(
          'trojan://passw0rd@trojan.example.com:443?sni=tls.example.com#T-01',
        ),
      );

      final e = endpoints.single as TrojanEndpoint;
      expect(e.password, 'passw0rd');
      expect(e.sni, 'tls.example.com');
      expect(e.port, 443);
    });

    test('hysteria2:// with mport + salamander → Hysteria2Endpoint', () {
      final endpoints = adapter.parseAndNormalize(
        raw(
          'hysteria2://letmein@hy2.example.com:8443?'
          'mport=20000-30000&obfs=salamander&obfs-password=peekaboo&insecure=1#HY-Fast',
        ),
      );

      final e = endpoints.single as Hysteria2Endpoint;
      expect(e.auth, 'letmein');
      expect(e.ports, '20000-30000');
      expect(e.obfsPassword, 'peekaboo');
      expect(e.insecure, isTrue);
    });

    test('tuic:// → TuicEndpoint with congestion_control', () {
      final endpoints = adapter.parseAndNormalize(
        raw(
          'tuic://uuid-here:passhere@tuic.example.com:443?'
          'congestion_control=bbr&alpn=h3&udp_relay_mode=native#TUIC-JP',
        ),
      );

      final e = endpoints.single as TuicEndpoint;
      expect(e.uuid, 'uuid-here');
      expect(e.password, 'passhere');
      expect(e.congestionControl, 'bbr');
      expect(e.udpRelayMode, 'native');
      expect(e.alpn, <String>['h3']);
    });
  });

  group('bundle + multi-line', () {
    test('base64 bundle of mixed links → union of variants', () {
      final bundle = base64Url.encode(
        utf8.encode(
          <String>[
            'vless://u1@a.example.com:443?#A',
            'trojan://p@b.example.com:443#B',
            'ss://${base64Url.encode(utf8.encode('rc4-md5:k'))}@c.example.com:1234#C',
          ].join('\n'),
        ),
      );

      final endpoints = adapter.parseAndNormalize(raw(bundle));

      expect(endpoints, hasLength(3));
      expect(endpoints[0], isA<VlessEndpoint>());
      expect(endpoints[1], isA<TrojanEndpoint>());
      expect(endpoints[2], isA<ShadowsocksEndpoint>());
    });

    test('malformed lines are skipped while good ones parse', () {
      final endpoints = adapter.parseAndNormalize(
        raw(
          <String>[
            'vless://u@d.example.com:443#Good',
            'not-a-link',
            'ftp://weird',
          ].join('\n'),
        ),
      );

      expect(endpoints, hasLength(1));
      expect(endpoints.single.tag, 'Good');
    });

    test('all-malformed input throws', () {
      expect(
        () => adapter.parseAndNormalize(raw('garbage\nmore-garbage')),
        throwsFormatException,
      );
    });
  });

  group('clash yaml', () {
    test('proxies block → typed variants incl. amnezia-wg-option', () {
      final endpoints = adapter.parseAndNormalize(
        raw('''
port: 7890
proxies:
  - name: "HK-AWG"
    type: wireguard
    server: 1.2.3.4
    port: 51820
    ip: 10.7.0.2
    private-key: ABCDEF=
    mtu: 1408
    udp: true
    peers:
      - server: 1.2.3.4
        port: 51820
        public-key: PUBKEY=
        allowed-ips:
          - 0.0.0.0/0
    amnezia-wg-option:
      jc: 5
      jmin: 30
      jmax: 1000
      s1: 56
      s2: 152
      h1: 1234567
      h2: 2345678
      h3: 3456789
      h4: 4567890
  - name: "US-Trojan"
    type: trojan
    server: us.example.com
    port: 443
    password: hunter2
    skip-cert-verify: true
  - name: "JP-Hy2"
    type: hysteria2
    server: jp.example.com
    port: 443
    password: pw123
    up: "50 Mbps"
    down: "200 Mbps"
''', url: Uri.parse('https://sub.example.test/clash')),
      );

      expect(endpoints, hasLength(3));
      final wg = endpoints[0] as WireGuardEndpoint;
      expect(wg.privateKey, 'ABCDEF=');
      expect(wg.addresses, <String>['10.7.0.2']);
      expect(wg.mtu, 1408);
      expect(wg.peers.single.publicKey, 'PUBKEY=');
      expect(wg.awg, isNotNull);
      expect(wg.awg!.jc, 5);
      expect(wg.awg!.s2, 152);
      expect(wg.awg!.h1, '1234567');

      final trojan = endpoints[1] as TrojanEndpoint;
      expect(trojan.password, 'hunter2');
      expect(trojan.allowInsecure, isTrue);

      final hy2 = endpoints[2] as Hysteria2Endpoint;
      expect(hy2.downMbps, 200);
      expect(hy2.upMbps, 50);
    });

    test(
      'mixed listeners are local inbounds — skipped, never sentinel endpoints',
      () {
        final endpoints = adapter.parseAndNormalize(
          raw('''
proxies:
  - name: "HK-Trojan"
    type: trojan
    server: hk.example.com
    port: 443
    password: pw
listeners:
  - name: mixed-in
    type: mixed
    port: 7890
''', url: Uri.parse('https://sub.example.test/listeners')),
        );

        // Only the proxy; no 127.0.0.1 uuid-local vmess sentinel.
        expect(endpoints, hasLength(1));
        final trojan = endpoints.single as TrojanEndpoint;
        expect(trojan.tag, 'HK-Trojan');
        expect(
          endpoints.whereType<VmessEndpoint>().where((e) => e.uuid == 'local'),
          isEmpty,
        );
      },
    );
  });

  group('sing-box json', () {
    test('outbounds + endpoints(awg) → typed variants', () {
      final endpoints = adapter.parseAndNormalize(
        raw(
          jsonEncode(<String, dynamic>{
            'outbounds': <dynamic>[
              <String, dynamic>{
                'type': 'vless',
                'tag': 'reality-out',
                'server': 'r.example.com',
                'server_port': 443,
                'uuid': 'uuid-x',
                'flow': 'xtls-rprx-vision',
                'tls': <String, dynamic>{
                  'enabled': true,
                  'server_name': 'www.microsoft.com',
                  'utls': <String, dynamic>{
                    'enabled': true,
                    'fingerprint': 'chrome',
                  },
                  'reality': <String, dynamic>{
                    'enabled': true,
                    'public_key': 'PBK',
                    'short_id': '0123',
                  },
                },
              },
              <String, dynamic>{
                'type': 'tuic',
                'tag': 'tuic-out',
                'server': 't.example.com',
                'server_port': 443,
                'uuid': 'u',
                'password': 'p',
                'congestion_control': 'bbr',
              },
              <String, dynamic>{'type': 'direct', 'tag': 'direct'},
            ],
            'endpoints': <dynamic>[
              <String, dynamic>{
                'type': 'awg',
                'tag': 'awg-out',
                'private_key': 'PRIV=',
                'address': <String>['10.7.0.2/32'],
                'jc': 6,
                'jmin': 8,
                'jmax': 48,
                's1': 123,
                'h1': '1217194092',
                'peers': <dynamic>[
                  <String, dynamic>{
                    'address': '5.6.7.8',
                    'port': 51820,
                    'public_key': 'PUB=',
                    'allowed_ips': <String>['0.0.0.0/0'],
                    'persistent_keepalive_interval': 25,
                  },
                ],
              },
            ],
          }),
        ),
      );

      expect(endpoints, hasLength(3));
      final vless = endpoints[0] as VlessEndpoint;
      expect(vless.realityPublicKey, 'PBK');
      expect(vless.realityShortId, '0123');
      expect(vless.fingerprint, 'chrome');
      expect(vless.sni, 'www.microsoft.com');

      final tuic = endpoints[1] as TuicEndpoint;
      expect(tuic.congestionControl, 'bbr');

      final awg = endpoints[2] as WireGuardEndpoint;
      expect(awg.awg!.jc, 6);
      expect(awg.awg!.jmax, 48);
      expect(awg.peers.single.endpoint, '5.6.7.8:51820');
      expect(awg.peers.single.persistentKeepalive, 25);
    });
  });

  group('wg ini', () {
    test(
      '[Interface] + [Peer] + Amnezia keys → WireGuardEndpoint with awg',
      () {
        const ini = '''
[Interface]
PrivateKey = aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789ABCDE=
Address = 10.7.0.2/32, fd00::2/128
MTU = 1420
Jc = 4
Jmin = 40
Jmax = 70
S1 = 86
S2 = 25
H1 = 1
H2 = 2
H3 = 3
H4 = 4

[Peer]
PublicKey = QWERTYUIOPASDFGHJKLZXCVBNM1234567890QWER=
PresharedKey = PSKPSKPSKPSKPSKPSKPSKPSKPSKPSKPSKPSKPSKPSKP=
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 9.8.7.6:51820
PersistentKeepalive = 25
''';
        final endpoints = adapter.parseAndNormalize(raw(ini));

        final wg = endpoints.single as WireGuardEndpoint;
        expect(
          wg.addresses,
          containsAll(<String>['10.7.0.2/32', 'fd00::2/128']),
        );
        expect(wg.mtu, 1420);
        expect(wg.peers, hasLength(1));
        expect(wg.peers.single.presharedKey, isNotNull);
        expect(wg.peers.single.endpoint, '9.8.7.6:51820');
        expect(wg.peers.single.persistentKeepalive, 25);
        expect(wg.awg, isNotNull);
        expect(wg.awg!.jc, 4);
        expect(wg.awg!.s1, 86);
        expect(wg.awg!.s2, 25);
        expect(wg.awg!.h1, '1');
      },
    );

    test('plain wg ini without Amnezia → awg null', () {
      const ini = '''
[Interface]
PrivateKey = ABC=
Address = 10.0.0.2/32

[Peer]
PublicKey = DEF=
Endpoint = 1.1.1.1:51820
AllowedIPs = 0.0.0.0/0
''';
      final endpoints = adapter.parseAndNormalize(raw(ini));
      final wg = endpoints.single as WireGuardEndpoint;
      expect(wg.awg, isNull);
    });

    test('WireSock masquerade Id/Ip/Ib keys round-trip into awg values', () {
      const ini = '''
[Interface]
PrivateKey = ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ABCDE=
Address = 10.7.0.2/32
Jc = 4
Jmin = 40
Jmax = 70
S1 = 86
S2 = 25
H1 = 1
H2 = 2
H3 = 3
H4 = 4
I1 = bV0kflF3SkdZV0p4T0dJd016QT0=
ID = 12345678
IP = 1234567890abcdef
IB = 87654321

[Peer]
PublicKey = QWERTYUIOPASDFGHJKLZXCVBNM1234567890QWER=
Endpoint = 9.8.7.6:51820
AllowedIPs = 0.0.0.0/0
''';
      final endpoints = adapter.parseAndNormalize(raw(ini));
      final wg = endpoints.single as WireGuardEndpoint;

      expect(wg.awg!.i1, 'bV0kflF3SkdZV0p4T0dJd016QT0=');
      expect(wg.awg!.id, '12345678');
      expect(wg.awg!.ip, '1234567890abcdef');
      expect(wg.awg!.ib, '87654321');
    });
  });

  group('cache', () {
    test('same url within 6h returns cached parse (no re-parse)', () {
      final sub = raw('trojan://pw@cached.example.com:443#C1');
      final first = adapter.parseAndNormalize(sub);
      final second = adapter.parseAndNormalize(sub);

      expect(identical(first, second), isTrue);
    });

    test('different url parses fresh', () {
      adapter.parseAndNormalize(
        raw(
          'trojan://pw@a.example.com:443#A',
          url: Uri.parse('https://x.test/1'),
        ),
      );
      final other = adapter.parseAndNormalize(
        raw(
          'vless://u@b.example.com:443#B',
          url: Uri.parse('https://x.test/2'),
        ),
      );
      expect(other.single, isA<VlessEndpoint>());
    });
  });
  group('multi-peer WG INI', () {
    test('two [Peer] sections → two peers, allowed_ips not merged', () {
      const ini = '''
[Interface]
PrivateKey = ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ABCDE=
Address = 10.7.0.2/32

[Peer]
PublicKey = PEER1PEER1PEER1PEER1PEER1PEER1PEER1PEER1PEER1PEE=
AllowedIPs = 10.1.0.0/16
Endpoint = 1.1.1.1:51820

[Peer]
PublicKey = PEER2PEER2PEER2PEER2PEER2PEER2PEER2PEER2PEER2PEE=
AllowedIPs = 10.2.0.0/16
Endpoint = 2.2.2.2:51820
''';
      final wg =
          adapter.parseAndNormalize(raw(ini)).single as WireGuardEndpoint;
      expect(wg.peers, hasLength(2));
      expect(wg.peers[0].endpoint, '1.1.1.1:51820');
      expect(wg.peers[0].allowedIps, <String>['10.1.0.0/16']);
      expect(wg.peers[1].endpoint, '2.2.2.2:51820');
      expect(wg.peers[1].allowedIps, <String>['10.2.0.0/16']);
    });
  });

  group('real-world base64 alphabets', () {
    test('vmess with standard-alphabet payload (contains +/)', () {
      final doc = <String, dynamic>{
        'v': '2',
        'ps': 'Mix',
        'add': 'm.example.com',
        'port': '443',
        'id': 'u',
        'aid': '0',
        'net': 'ws',
        'scy': 'auto',
        'tls': 'tls',
        'path': '/ws+extra/x',
      };
      final payload = base64.encode(utf8.encode(jsonEncode(doc)));
      final e =
          adapter.parseAndNormalize(raw('vmess://$payload')).single
              as VmessEndpoint;
      expect(e.address, 'm.example.com');
      expect(e.wsPath, '/ws+extra/x');
    });
  });

  group('fuzz: malformed input throws FormatException, not TypeError', () {
    test('clash port as string / missing server', () {
      expect(
        () => adapter.parseAndNormalize(
          raw(
            'proxies:\n  - name: bad\n    type: ss\n    port: "443"\n    cipher: a\n    password: b',
            url: Uri.parse('https://f.test/1'),
          ),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => adapter.parseAndNormalize(
          raw(
            'proxies:\n  - name: bad\n    type: ss\n    cipher: a\n    password: b',
            url: Uri.parse('https://f.test/2'),
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('malformed base64 throws FormatException, never StackOverflow', () {
      // Regression: decodeBase64Flex used to recurse on itself in the catch
      // branch, overflowing the stack on any payload standard base64
      // rejects. Both alphabets must fail fast instead.
      expect(() => decodeBase64Flex('!!!not-base64!!!'), throwsFormatException);
      expect(() => decodeBase64Flex('a'), throwsFormatException);
      // URL-safe payload without padding still decodes (fallback path).
      final payload = base64Url
          .encode(utf8.encode('{"add":"a"}'))
          .replaceAll('=', '');
      expect(decodeBase64Flex(payload), contains('"add"'));
    });

    test('vmess aid float / port float → FormatException', () {
      final doc1 = <String, dynamic>{
        'add': 'a',
        'port': 8443,
        'id': 'u',
        'aid': 0.5,
      };
      final doc2 = <String, dynamic>{
        'add': 'a',
        'port': 8443.5,
        'id': 'u',
        'aid': 0,
      };
      expect(
        () => adapter.parseAndNormalize(
          raw('vmess://${base64.encode(utf8.encode(jsonEncode(doc1)))}'),
        ),
        throwsFormatException,
      );
      expect(
        () => adapter.parseAndNormalize(
          raw('vmess://${base64.encode(utf8.encode(jsonEncode(doc2)))}'),
        ),
        throwsFormatException,
      );
    });

    // Audit W2.6 regression cluster: one malformed node must never abort
    // the whole import, and credential/host fields previously dropped or
    // corrupted must survive parsing.
    group('W2.6 hardening', () {
      test('malformed vmess field throws FormatException, not TypeError', () {
        // add present but id is an int (wrong type) — a blind `as String`
        // threw TypeError which escaped parseShareLines and killed the
        // entire import.
        final doc = <String, dynamic>{
          'add': 'jp.example.com',
          'port': 8443,
          'id': 12345, // wrong type
        };
        expect(
          () => adapter.parseAndNormalize(
            raw('vmess://${base64.encode(utf8.encode(jsonEncode(doc)))}'),
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e is! TypeError,
              'not a TypeError',
              isTrue,
            ),
          ),
        );
      });

      test('missing vmess add/id throw FormatException', () {
        final noAdd = base64.encode(
          utf8.encode(jsonEncode(<String, dynamic>{'id': 'x', 'port': 1})),
        );
        final noId = base64.encode(
          utf8.encode(jsonEncode(<String, dynamic>{'add': 'h', 'port': 1})),
        );
        expect(
          () => adapter.parseAndNormalize(raw('vmess://$noAdd')),
          throwsFormatException,
        );
        expect(
          () => adapter.parseAndNormalize(raw('vmess://$noId')),
          throwsFormatException,
        );
      });

      test('good line survives a TypeError-shaped bad sibling line', () {
        final good = base64Url.encode(
          utf8.encode(
            jsonEncode(<String, dynamic>{
              'add': 'ok.example.com',
              'port': 443,
              'id': 'uuid-1',
            }),
          ),
        );
        final badDoc = <String, dynamic>{
          'add': <String>['not', 'a', 'string'], // list where string expected
          'port': 443,
          'id': 'uuid-2',
        };
        final endpoints = adapter.parseShareLines(<String>[
          'vmess://$good',
          'vmess://${base64Url.encode(utf8.encode(jsonEncode(badDoc)))}',
        ]);
        expect(endpoints, hasLength(1));
        expect((endpoints.single as VmessEndpoint).address, 'ok.example.com');
      });

      test('vmess ws Host header (v2rayN host key) is preserved', () {
        final doc = base64.encode(
          utf8.encode(
            jsonEncode(<String, dynamic>{
              'add': 'jp.example.com',
              'port': 443,
              'id': 'b831381d-6324-4d53-ad4f-8cda48b30811',
              'net': 'ws',
              'path': '/ws',
              'host': 'cdn.example.com',
              'tls': 'tls',
            }),
          ),
        );
        final e =
            adapter.parseAndNormalize(raw('vmess://$doc')).single
                as VmessEndpoint;
        expect(e.transport, isNotNull);
        expect(e.transport!.host, 'cdn.example.com');
        expect(e.transport!.path, '/ws');
      });

      test('percent-encoded trojan password is decoded', () {
        // password with '@' encoded: p%40ss → p@ss
        final e =
            adapter.parseAndNormalize(
                  raw('trojan://p%40ss@trojan.example.com:443#enc'),
                )
                .single as TrojanEndpoint;
        expect(e.password, 'p@ss');
      });

      test('percent-encoded hysteria2 auth is decoded', () {
        final e =
            adapter.parseAndNormalize(
                  raw('hysteria2://au%2Fth@h.example.com:443#h'),
                )
                .single as Hysteria2Endpoint;
        expect(e.auth, 'au/th');
      });

      test('percent-encoded tuic uuid:password is decoded', () {
        final e =
            adapter.parseAndNormalize(
                  raw('tuic://u%40id:pw%3Ass@t.example.com:443#t'),
                )
                .single as TuicEndpoint;
        expect(e.uuid, 'u@id');
        expect(e.password, 'pw:ss');
      });

      test('out-of-range share-link port throws FormatException', () {
        expect(
          () => adapter.parseAndNormalize(
            raw('trojan://pw@h.example.com:99999#x'),
          ),
          throwsA(anyOf(isA<FormatException>(), isA<RangeError>())),
        );
      });

      test('clash hysteria2 scalar obfs form does not abort the import', () {
        const yaml = '''
proxies:
  - name: hy-scalar
    type: hysteria2
    server: hy.example.com
    port: 443
    password: letmein
    obfs: salamander
  - name: hy-map
    type: hysteria2
    server: hy2.example.com
    port: 443
    password: letmein
    obfs:
      type: salamander
      password: peekaboo
''';
        final endpoints = adapter.parseAndNormalize(raw(yaml));
        expect(endpoints, hasLength(2));
        final scalar = endpoints[0] as Hysteria2Endpoint;
        final map = endpoints[1] as Hysteria2Endpoint;
        expect(scalar.tag, 'hy-scalar');
        expect(map.obfsPassword, 'peekaboo');
      });
    });
  });
}
