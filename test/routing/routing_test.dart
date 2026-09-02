import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yourvpn/core/network/http_cache.dart';
import 'package:yourvpn/modules/geo/geo_asset.dart';
import 'package:yourvpn/modules/routing/config_assembler.dart';
import 'package:yourvpn/modules/routing/routing_compiler.dart';
import 'package:yourvpn/modules/routing/routing_policy.dart';

final String singBoxExe = p.join(Directory.current.path, 'windows', 'sing-box.exe');

bool get singBoxAvailable => File(singBoxExe).existsSync();

const awgEndpointJson = '''
{
  "type": "awg",
  "tag": "awg-hkg-02",
  "private_key": "eCbtX5g5Pof3zH0Gu6dzulIzLB0B5xj+OhIfgVtWu1A=",
  "address": ["10.7.0.2/32"],
  "jc": 5,
  "jmin": 30,
  "jmax": 1000,
  "s1": 56,
  "s2": 152,
  "h1": "1234567",
  "h2": "2345678",
  "h3": "3456789",
  "h4": "4567890",
  "peers": [
    {
      "address": "203.0.113.10",
      "port": 51820,
      "public_key": "7f3f0a5df0c497ef3f4a05c99a3a2d8d3c4b5a6e7f8091a2b3c4d5e6f708192a",
      "allowed_ips": ["0.0.0.0/0", "::/0"],
      "persistent_keepalive_interval": 25
    }
  ]
}
''';

RoutingPolicy testPolicy() => const RoutingPolicy(
  rules: <RouteRule>[
    RouteRule(
      outbound: 'DIRECT',
      domainSuffixes: <String>['cn'],
      ruleSets: <String>['geosite-cn', 'geoip-cn'],
    ),
    RouteRule(
      outbound: 'BLOCK',
      processNames: <String>['steam.exe'],
    ),
    RouteRule(
      outbound: 'DIRECT',
      logicalMode: 'and',
      rules: <RouteRule>[
        RouteRule(
          processNames: <String>['chrome.exe'],
          invert: true,
        ),
        RouteRule(wifiSsids: <String>['Home WiFi']),
      ],
    ),
  ],
);

Directory tempDir() {
  final dir = Directory.systemTemp.createTempSync('routing_test');
  return dir;
}

GeoAsset geoFor(Directory dir) {
  return GeoAsset(
    cacheDir: Directory('${dir.path}/cache'),
    initialDir: Directory('rule_sets/initial_assets'),
    http: HttpCache(fetch: (url, headers) async => throw const SocketException('offline')),
  );
}

void main() {
  late Directory dir;
  setUp(() => dir = tempDir());
  tearDown(() => dir.deleteSync(recursive: true));

  group('RoutingCompiler', () {
    test('happy path: domain/process_name + rule_set + invert + logical and', () {
      final result = const RoutingCompiler().compile(testPolicy());

      expect(result.isValid, isTrue, reason: result.validationErrors.join('; '));
      expect(result.rulesJson, hasLength(3));

      final first = result.rulesJson[0];
      expect(first['domain_suffix'], <String>['cn']);
      expect(first['rule_set'], <String>['geosite-cn', 'geoip-cn']);
      expect(first['outbound'], 'DIRECT');

      final second = result.rulesJson[1];
      expect(second['process_name'], <String>['steam.exe']);
      expect(second['action'], 'reject');

      final third = result.rulesJson[2];
      expect(third['type'], 'logical');
      expect(third['mode'], 'and');
      expect(third['rules'], hasLength(2));
      expect(third['rules'][0]['invert'], isTrue);
      expect(third['rules'][0].containsKey('outbound'), isFalse);
      expect(third['outbound'], 'DIRECT');

      expect(result.ruleSetTags, <String>{'geosite-cn', 'geoip-cn'});
    });

    test('rule-set tag dedup', () {
      final result = const RoutingCompiler().compile(
        const RoutingPolicy(
          rules: <RouteRule>[
            RouteRule(
              outbound: 'DIRECT',
              ruleSets: <String>['geosite-cn', 'geosite-cn'],
            ),
            RouteRule(
              outbound: 'BLOCK',
              ruleSets: <String>['geosite-cn'],
            ),
          ],
        ),
      );

      expect(result.ruleSetTags, <String>{'geosite-cn'});
    });

    test('invalid rule-set tag surfaces in errors, not thrown', () {
      final result = const RoutingCompiler().compile(
        const RoutingPolicy(
          rules: <RouteRule>[
            RouteRule(
              outbound: 'DIRECT',
              ruleSets: <String>['not-in-registry'],
            ),
          ],
        ),
      );

      expect(result.isValid, isFalse);
      expect(result.validationErrors.single, contains('not-in-registry'));
    });

    test('empty rule accumulates error', () {
      final result = const RoutingCompiler().compile(
        const RoutingPolicy(
          rules: <RouteRule>[RouteRule(outbound: 'DIRECT')],
        ),
      );

      expect(result.isValid, isFalse);
      expect(result.validationErrors.single, contains('no condition fields'));
    });

    test('multiple errors at once (30-field editor shows all)', () {
      final result = const RoutingCompiler().compile(
        const RoutingPolicy(
          rules: <RouteRule>[
            RouteRule(outbound: 'DIRECT'),
            RouteRule(
              outbound: 'DIRECT',
              ruleSets: <String>['bogus-1'],
            ),
            RouteRule(
              outbound: 'DIRECT',
              logicalMode: 'xor',
              rules: <RouteRule>[RouteRule(domains: <String>['only-one'])],
            ),
          ],
        ),
      );

      expect(result.isValid, isFalse);
      expect(result.validationErrors, hasLength(4));
      expect(result.validationErrors[0], contains('no condition fields'));
      expect(result.validationErrors[1], contains('bogus-1'));
      expect(result.validationErrors[2], contains('xor'));
      expect(result.validationErrors[3], contains('at least 2 sub-rules'));
    });

    test('logical rule without outbound accumulates sub-rule outbound error', () {
      final result = const RoutingCompiler().compile(
        const RoutingPolicy(
          rules: <RouteRule>[
            RouteRule(
              logicalMode: 'or',
              rules: <RouteRule>[
                RouteRule(domains: <String>['a.com'], outbound: 'PROXY'),
                RouteRule(domains: <String>['b.com']),
              ],
            ),
          ],
        ),
      );

      expect(result.isValid, isFalse);
      expect(result.validationErrors.any((e) => e.contains('sub-rule must not set outbound')), isTrue);
    });
  });

  group('ConfigAssembler → sing-box check', () {
    test('compiled policy produces a config the real sing-box accepts', () async {
      final geo = geoFor(dir);
      final assembler = ConfigAssembler(geoAsset: geo);
      final config = assembler.build(
        endpointJson: awgEndpointJson,
        policy: testPolicy(),
      );
      final file = File('${dir.path}/config.json');
      await file.writeAsString(jsonEncode(config));

      final result = Process.runSync(
        singBoxExe,
        <String>['check', '-c', file.path],
      );
      expect(
        result.exitCode,
        0,
        reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
      );
    });

    test('rule_set entries reference compiled tags only', () {
      final geo = geoFor(dir);
      final assembler = ConfigAssembler(geoAsset: geo);
      final config = assembler.build(
        endpointJson: awgEndpointJson,
        policy: testPolicy(),
      );

      final route = config['route'] as Map<String, dynamic>;
      final ruleSet = route['rule_set'] as List<Map<String, dynamic>>;
      expect(ruleSet, hasLength(2));
      expect(ruleSet.map((e) => e['tag']), containsAll(<String>['geosite-cn', 'geoip-cn']));
      for (final entry in ruleSet) {
        expect(entry['type'], 'remote');
        expect(entry['format'], 'binary');
        expect(entry['download_detour'], 'PROXY');
        expect(entry['update_interval'], '24h');
      }
    });
  });

  group('SRS round-trip with real binary', () {
    test('geosite-cn.srs decompiles (initial asset is a valid rule-set)', () {
      final result = Process.runSync(
        singBoxExe,
        <String>[
          'rule-set',
          'decompile',
          '-o',
          '${dir.path}/geosite-cn.json',
          'rule_sets/initial_assets/geosite-cn.srs',
        ],
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final json = jsonDecode(File('${dir.path}/geosite-cn.json').readAsStringSync())
          as Map<String, dynamic>;
      expect(json['version'], 1);
      expect(json['rules'], isNotEmpty);
    });
  });
}


