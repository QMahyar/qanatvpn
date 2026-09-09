import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qanatvpn/modules/vpn/amnezia/awg_config.dart';
import 'package:qanatvpn/utils/amnezia_values.dart';

final String singBoxExe = p.join(
  Directory.current.path,
  'windows',
  'sing-box.exe',
);

const goodPrivateKey = 'eCbtX5g5Pof3zH0Gu6dzulIzLB0B5xj+OhIfgVtWu1A=';
const goodPeerKey = 'fz8KXfDEl+8/SgXJmjotjTxLWm5/gJGis8TV5vcIGSo=';

bool singBoxAvailableForTest() => File('windows/sing-box.exe').existsSync();

void main() {
  group('presets', () {
    test('balanced preset validates cleanly with good endpoint material', () {
      final config = AwgProfile.fromPreset(
        AwgProfile.balanced,
        privateKey: goodPrivateKey,
        peerPublicKey: goodPeerKey,
        peerEndpoint: '203.0.113.10:51820',
        addresses: <String>['10.7.0.2/32'],
      );

      expect(config.isValid, isTrue, reason: config.validate().join('; '));
      expect(config.values.jc, 5);
      expect(config.values.s2, 152);
      expect(config.values.h1, '1234567');
    });

    test('all three presets hold the header-distinct invariant', () {
      for (final profile in AwgProfile.values) {
        final config = AwgProfile.fromPreset(
          profile,
          privateKey: goodPrivateKey,
          peerPublicKey: goodPeerKey,
          peerEndpoint: '203.0.113.10:51820',
          addresses: <String>['10.7.0.2/32'],
        );
        expect(
          config.validate().any((e) => e.contains('distinct')),
          isFalse,
          reason: '${profile.label}: ${config.validate()}',
        );
      }
    });

    test('labels expose preset names for the UI', () {
      expect(AwgProfile.quicMimic.label, 'QUIC mimic');
      expect(AwgProfile.balanced.label, 'Balanced');
      expect(AwgProfile.stealth.label, 'Stealth');
    });
  });

  group('generateRandom', () {
    test('100 draws: H distinct, S1+56≠S2, Jmax<MTU(1408)', () {
      for (var i = 0; i < 100; i++) {
        final config = AwgProfile.generateRandom(
          privateKey: goodPrivateKey,
          peerPublicKey: goodPeerKey,
          peerEndpoint: '203.0.113.10:51820',
          addresses: <String>['10.7.0.2/32'],
        );
        final v = config.values;
        final headers = <String>[v.h1!, v.h2!, v.h3!, v.h4!];
        expect(headers.toSet().length, 4, reason: 'draw $i: $headers');
        expect(v.s1! + 56, isNot(v.s2), reason: 'draw $i');
        expect(v.jmax!, lessThan(1408), reason: 'draw $i');
        expect(config.isValid, isTrue, reason: 'draw $i: ${config.validate()}');
      }
    });
  });

  group('validate catches', () {
    AwgConfig buildWith(AwgValues values) => awgConfigForTest(
      values: values,
      privateKey: goodPrivateKey,
      peerPublicKey: goodPeerKey,
      peerEndpoint: '203.0.113.10:51820',
      addresses: <String>['10.7.0.2/32'],
      mtu: 1408,
    );

    test('header collision (H1 == H2)', () {
      final config = buildWith(
        const AwgValues(
          jc: 5,
          jmin: 30,
          jmax: 1000,
          s1: 56,
          s2: 152,
          h1: '123',
          h2: '123',
          h3: '456',
          h4: '789',
        ),
      );

      expect(config.validate(), contains(contains('distinct')));
    });

    test('S1 + 56 == S2', () {
      final config = buildWith(
        const AwgValues(
          jc: 5,
          jmin: 30,
          jmax: 1000,
          s1: 96,
          s2: 152,
          h1: '1',
          h2: '2',
          h3: '3',
          h4: '4',
        ),
      );

      expect(config.validate(), contains(contains('S1 + 56')));
    });

    test('Jmax >= MTU', () {
      final config = awgConfigForTest(
        values: const AwgValues(jmax: 2000, h1: '1', h2: '2', h3: '3', h4: '4'),
        privateKey: goodPrivateKey,
        peerPublicKey: goodPeerKey,
        peerEndpoint: '203.0.113.10:51820',
        addresses: <String>['10.7.0.2/32'],
        mtu: 1408,
      );

      expect(config.validate(), contains(contains('Jmax')));
    });

    test('short key', () {
      final config = awgConfigForTest(
        values: const AwgValues(h1: '1', h2: '2', h3: '3', h4: '4'),
        privateKey: 'tooshort',
        peerPublicKey: goodPeerKey,
        peerEndpoint: '203.0.113.10:51820',
        addresses: <String>['10.7.0.2/32'],
        mtu: 1408,
      );

      expect(config.validate(), contains(contains('private_key')));
    });

    test('bad endpoint and no addresses', () {
      final config = awgConfigForTest(
        values: const AwgValues(h1: '1', h2: '2', h3: '3', h4: '4'),
        privateKey: goodPrivateKey,
        peerPublicKey: goodPeerKey,
        peerEndpoint: 'no-port-here',
        addresses: const <String>[],
        mtu: 1408,
      );

      final errors = config.validate();
      expect(errors, contains(contains('endpoint')));
      expect(errors, contains(contains('address')));
    });
  });

  group('toEndpointJson', () {
    test('emits fork-accepted awg endpoint (real sing-box check)',
      skip: singBoxAvailableForTest() ? false : 'needs windows/sing-box.exe',
      () async {
      final config = AwgProfile.fromPreset(
        AwgProfile.balanced,
        privateKey: goodPrivateKey,
        peerPublicKey: goodPeerKey,
        peerEndpoint: '203.0.113.10:51820',
        addresses: <String>['10.7.0.2/32'],
      );
      final json = config.toEndpointJson();
      expect(json['type'], 'awg');
      expect(json['jc'], 5);
      expect(
        (json['peers'] as List<dynamic>).first,
        containsPair('port', 51820),
      );

      final singBox = File(singBoxExe);
      final configJson = <String, dynamic>{
        'log': <String, dynamic>{'level': 'info'},
        'endpoints': <dynamic>[json],
      };
      final file = File(
        '${Directory.systemTemp.path}/awg_config_test_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await file.writeAsString(jsonEncode(configJson));
      final result = Process.runSync(singBox.path, <String>[
        'check',
        '-c',
        file.path,
      ]);
      await file.delete();
      expect(
        result.exitCode,
        0,
        reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
      );
    });

    test(
      'Id/Ip/Ib never reach engine JSON (fork FATALs on unknown fields)',
      () {
        final config = awgConfigForTest(
          values: const AwgValues(
            jc: 5,
            jmin: 30,
            jmax: 1000,
            s1: 56,
            s2: 152,
            h1: '1234567',
            h2: '2345678',
            h3: '3456789',
            h4: '4567890',
            id: '12345678',
            ip: '1234567890abcdef',
            ib: '87654321',
          ),
          privateKey: goodPrivateKey,
          peerPublicKey: goodPeerKey,
          peerEndpoint: '203.0.113.10:51820',
          addresses: <String>['10.7.0.2/32'],
          mtu: 1408,
        );

        final json = config.toEndpointJson();
        expect(json.containsKey('id'), isFalse);
        expect(json.containsKey('ip'), isFalse);
        expect(json.containsKey('ib'), isFalse);
        // But the full model keeps them for editor round-trips.
        expect(config.values.id, '12345678');
        expect(config.validate(), isEmpty);
      },
    );

    test('IPv6 bracketed endpoint splits host and port correctly', () {
      final config = awgConfigForTest(
        values: const AwgValues(h1: '1', h2: '2', h3: '3', h4: '4'),
        privateKey: goodPrivateKey,
        peerPublicKey: goodPeerKey,
        peerEndpoint: '[2001:db8::1]:51820',
        addresses: <String>['10.7.0.2/32'],
        mtu: 1408,
      );

      expect(config.validate(), isEmpty);
      final json = config.toEndpointJson();
      final peer =
          (json['peers'] as List<dynamic>).first as Map<String, dynamic>;
      expect(peer['address'], '2001:db8::1');
      expect(peer['port'], 51820);
    });

    test('bare IPv6 endpoint (no brackets) is rejected by validate', () {
      final config = awgConfigForTest(
        values: const AwgValues(h1: '1', h2: '2', h3: '3', h4: '4'),
        privateKey: goodPrivateKey,
        peerPublicKey: goodPeerKey,
        peerEndpoint: '2001:db8::1:51820',
        addresses: <String>['10.7.0.2/32'],
        mtu: 1408,
      );

      expect(config.validate(), contains(contains('brackets')));
    });

    test('IPv6 config passes real sing-box check',
        skip: singBoxAvailableForTest() ? false : 'needs windows/sing-box.exe',
        () {
      final config = awgConfigForTest(
        values: const AwgValues(
          jc: 5,
          jmin: 30,
          jmax: 1000,
          s1: 56,
          s2: 152,
          h1: '1234567',
          h2: '2345678',
          h3: '3456789',
          h4: '4567890',
        ),
        privateKey: goodPrivateKey,
        peerPublicKey: goodPeerKey,
        peerEndpoint: '[2001:db8::1]:51820',
        addresses: <String>['10.7.0.2/32'],
        mtu: 1408,
      );
      final singBox = File(singBoxExe);
      final file = File(
        '${Directory.systemTemp.path}/awg_v6_test_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      file.writeAsStringSync(
        jsonEncode(<String, dynamic>{
          'log': <String, dynamic>{'level': 'info'},
          'endpoints': <dynamic>[config.toEndpointJson()],
        }),
      );
      final result = Process.runSync(singBox.path, <String>[
        'check',
        '-c',
        file.path,
      ]);
      file.deleteSync();
      expect(result.exitCode, 0, reason: result.stderr.toString());
    });
  });

  group('masquerade Id/Ip/Ib validation', () {
    AwgConfig buildWith(AwgValues values) => awgConfigForTest(
      values: values,
      privateKey: goodPrivateKey,
      peerPublicKey: goodPeerKey,
      peerEndpoint: '203.0.113.10:51820',
      addresses: <String>['10.7.0.2/32'],
      mtu: 1408,
    );

    test('valid hex accepted', () {
      expect(
        buildWith(const AwgValues(id: 'deadBEEF12345678')).validate(),
        isEmpty,
      );
    });

    test('valid decimal accepted', () {
      expect(buildWith(const AwgValues(id: '12345678')).validate(), isEmpty);
    });

    test('non-hex rejected', () {
      expect(
        buildWith(const AwgValues(id: 'zzzz-not-hex')).validate(),
        contains(contains('Id')),
      );
    });

    test('oversized hex rejected', () {
      expect(
        buildWith(const AwgValues(ip: '1234567890abcdef0')).validate(),
        contains(contains('Ip')),
      );
    });

    test('null Ib passes', () {
      expect(buildWith(const AwgValues()).validate(), isEmpty);
    });
  });
}
