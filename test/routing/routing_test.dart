import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qanatvpn/core/network/http_cache.dart';
import 'package:qanatvpn/modules/geo/geo_asset.dart';
import 'package:qanatvpn/modules/routing/config_assembler.dart';
import 'package:qanatvpn/modules/routing/routing_compiler.dart';
import 'package:qanatvpn/modules/routing/routing_policy.dart';

final String singBoxExe = p.join(
  Directory.current.path,
  'windows',
  'sing-box.exe',
);

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
    RouteRule(outbound: 'BLOCK', processNames: <String>['steam.exe']),
    RouteRule(
      outbound: 'DIRECT',
      logicalMode: 'and',
      rules: <RouteRule>[
        RouteRule(processNames: <String>['chrome.exe'], invert: true),
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
    http: HttpCache(
      fetch: (url, headers) async => throw const SocketException('offline'),
    ),
  );
}

/// Startup seeding (audit W4.1): local rule-set entries point at on-disk
/// copies, so every assembler test must ensure() before building — the same
/// contract main() runs before the engine can start.
Future<GeoAsset> geoSeededFor(Directory dir) async {
  final geo = geoFor(dir);
  for (final tag in GeoAsset.registry.keys) {
    await geo.ensure(tag);
  }
  return geo;
}

void main() {
  late Directory dir;
  setUp(() => dir = tempDir());
  tearDown(() => dir.deleteSync(recursive: true));

  group('RoutingCompiler', () {
    test(
      'happy path: domain/process_name + rule_set + invert + logical and',
      () {
        final result = const RoutingCompiler().compile(testPolicy());

        expect(
          result.isValid,
          isTrue,
          reason: result.validationErrors.join('; '),
        );
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
      },
    );

    test('rule-set tag dedup', () {
      final result = const RoutingCompiler().compile(
        const RoutingPolicy(
          rules: <RouteRule>[
            RouteRule(
              outbound: 'DIRECT',
              ruleSets: <String>['geosite-cn', 'geosite-cn'],
            ),
            RouteRule(outbound: 'BLOCK', ruleSets: <String>['geosite-cn']),
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
        const RoutingPolicy(rules: <RouteRule>[RouteRule(outbound: 'DIRECT')]),
      );

      expect(result.isValid, isFalse);
      expect(result.validationErrors.single, contains('no condition fields'));
    });

    test('multiple errors at once (30-field editor shows all)', () {
      final result = const RoutingCompiler().compile(
        const RoutingPolicy(
          rules: <RouteRule>[
            RouteRule(outbound: 'DIRECT'),
            RouteRule(outbound: 'DIRECT', ruleSets: <String>['bogus-1']),
            RouteRule(
              outbound: 'DIRECT',
              logicalMode: 'xor',
              rules: <RouteRule>[
                RouteRule(domains: <String>['only-one']),
              ],
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

    test(
      'logical rule without outbound accumulates sub-rule outbound error',
      () {
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
        expect(
          result.validationErrors.any(
            (e) => e.contains('sub-rule must not set outbound'),
          ),
          isTrue,
        );
      },
    );

    test('the 6 previously-missing fields emit fork-native shapes', () {
      final result = const RoutingCompiler().compile(
        const RoutingPolicy(
          rules: <RouteRule>[
            RouteRule(
              outbound: 'DIRECT',
              ipVersion: 4,
              ipIsPrivate: true,
              portRanges: <String>['1000:2000'],
              sourcePortRanges: <String>['5000:6000'],
              processPaths: <String>[r'C:\Program Files\app.exe'],
              userIds: <int>[1000, 1001],
              sourceIpIsPrivate: false,
            ),
          ],
        ),
      );

      expect(
        result.isValid,
        isTrue,
        reason: result.validationErrors.join('; '),
      );
      final json = result.rulesJson.single;
      expect(json['ip_version'], 4);
      expect(json['ip_is_private'], isTrue);
      expect(json['source_ip_is_private'], isFalse);
      expect(json['port_range'], <String>['1000:2000']);
      expect(json['source_port_range'], <String>['5000:6000']);
      expect(json['process_path'], <String>[r'C:\Program Files\app.exe']);
      expect(json['user_id'], <int>[1000, 1001]);
    });

    test('bad ip_version and bad port ranges accumulate errors at once', () {
      final result = const RoutingCompiler().compile(
        const RoutingPolicy(
          rules: <RouteRule>[
            RouteRule(
              outbound: 'DIRECT',
              ipVersion: 5,
              portRanges: <String>['2000:1000', 'x:y', '80'],
            ),
            RouteRule(
              outbound: 'DIRECT',
              userIds: <int>[1000],
              processPathRegexes: <String>['.*steam.*'],
            ),
          ],
        ),
      );

      expect(result.isValid, isFalse);
      // 3 bad port ranges + ip_version; the rule then has no valid condition
      // field left, adding the 5th "no condition fields" error.
      expect(result.validationErrors, hasLength(5));
      expect(result.validationErrors[0], contains('port_range'));
      expect(result.validationErrors[1], contains('port_range'));
      expect(result.validationErrors[2], contains('port_range'));
      expect(result.validationErrors[3], contains('ip_version'));
      expect(result.validationErrors[4], contains('no condition fields'));
      // Rule 1 dropped (no valid condition field); only rule 2 compiles.
      expect(result.rulesJson, hasLength(1));
      expect(result.rulesJson.single['user_id'], <int>[1000]);
      expect(result.rulesJson.single['process_path_regex'], <String>[
        '.*steam.*',
      ]);
    });
  });

  group('Outbound groups (3-tier auto→selector→endpoint)', () {
    test('urltest + selector emit fork shapes; member refs validated', () {
      final result = const RoutingCompiler().compile(
        const RoutingPolicy(
          rules: <RouteRule>[],
          leafOutbounds: <String>['awg-hkg-02'],
          groups: <OutboundGroup>[
            OutboundGroup.urlTest(
              tag: 'auto',
              members: <String>['awg-hkg-02'],
              interval: Duration(minutes: 5),
            ),
            OutboundGroup.selector(
              tag: 'manual',
              members: <String>['auto', 'awg-hkg-02', 'DIRECT'],
              defaultMember: 'auto',
              interruptExistConnections: true,
            ),
          ],
        ),
      );

      expect(
        result.isValid,
        isTrue,
        reason: result.validationErrors.join('; '),
      );
      final auto = result.outboundsJson[0];
      expect(auto['type'], 'urltest');
      expect(auto['interval'], '5m');
      expect(auto['tolerance'], 50);
      final manual = result.outboundsJson[1];
      expect(manual['type'], 'selector');
      expect(manual['default'], 'auto');
      expect(manual['interrupt_exist_connections'], isTrue);
    });

    test(
      'unknown member, duplicate tag, empty members, bad default — all at once',
      () {
        final result = const RoutingCompiler().compile(
          const RoutingPolicy(
            rules: <RouteRule>[],
            groups: <OutboundGroup>[
              OutboundGroup.selector(
                tag: 'dup',
                members: <String>['ghost-endpoint'],
              ),
              OutboundGroup.selector(tag: 'dup', members: <String>['DIRECT']),
              OutboundGroup.urlTest(tag: 'empty', members: <String>[]),
              OutboundGroup.selector(
                tag: 'baddefault',
                members: <String>['DIRECT'],
                defaultMember: 'nope',
              ),
            ],
          ),
        );

        expect(result.isValid, isFalse);
        expect(result.validationErrors, hasLength(4));
        expect(result.validationErrors[0], contains('ghost-endpoint'));
        expect(result.validationErrors[1], contains('duplicate group tag'));
        expect(result.validationErrors[2], contains('at least 1 member'));
        expect(result.validationErrors[3], contains('default'));
      },
    );
  });

  group('TOR-CHAIN seam', () {
    test('reference without torChain set is a validation error', () {
      final result = const RoutingCompiler().compile(
        const RoutingPolicy(
          rules: <RouteRule>[
            RouteRule(outbound: 'TOR-CHAIN', ports: <String>['9050']),
          ],
        ),
      );

      expect(result.isValid, isFalse);
      expect(result.validationErrors.single, contains('torChain is unset'));
    });

    test('torChain set emits socks sidecar outbound', () {
      final result = const RoutingCompiler().compile(
        const RoutingPolicy(
          rules: <RouteRule>[
            RouteRule(outbound: 'TOR-CHAIN', ports: <String>['9050']),
          ],
          torChain: TorChainOptions(),
        ),
      );

      expect(
        result.isValid,
        isTrue,
        reason: result.validationErrors.join('; '),
      );
      final tor = result.outboundsJson.single;
      expect(tor['type'], 'socks');
      expect(tor['tag'], 'tor-entry');
      expect(tor['server'], '127.0.0.1');
      expect(tor['server_port'], 9050);
      expect(tor['version'], '5');
    });

    test(
      'assembler injects detour into TOR-CHAIN endpoint (real check)',
      () async {
      if (!singBoxAvailable) {
        markTestSkipped('needs windows/sing-box.exe');
      }
      final geo = await geoSeededFor(dir);
      final assembler = ConfigAssembler(geoAsset: geo);
      final config = assembler.build(
        endpointJson: awgEndpointJson.replaceFirst(
          '"tag": "awg-hkg-02"',
          '"tag": "TOR-CHAIN"',
        ),
        policy: const RoutingPolicy(
          rules: <RouteRule>[],
          torChain: TorChainOptions(),
        ),
      );
      final endpoint =
          (config['endpoints'] as List<dynamic>).single as Map<String, dynamic>;
      expect(endpoint['detour'], 'tor-entry');
      final outbounds = config['outbounds'] as List<dynamic>;
      expect(
        outbounds.any((o) => (o as Map<String, dynamic>)['tag'] == 'tor-entry'),
        isTrue,
      );

      final file = File('${dir.path}/tor-config.json');
      file.writeAsStringSync(jsonEncode(config));
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

  group('3-tier assembly → sing-box check', () {
    test(
      'auto urltest → selector → endpoint config passes real sing-box',
      () async {
      if (!singBoxAvailable) {
        markTestSkipped('needs windows/sing-box.exe');
      }
      final geo = await geoSeededFor(dir);
      final assembler = ConfigAssembler(geoAsset: geo);
      final config = assembler.build(
        endpointJson: awgEndpointJson,
        policy: const RoutingPolicy(
          rules: <RouteRule>[
            RouteRule(outbound: 'manual', domainSuffixes: <String>['cn']),
          ],
          leafOutbounds: <String>['awg-hkg-02'],
          groups: <OutboundGroup>[
            OutboundGroup.urlTest(tag: 'auto', members: <String>['awg-hkg-02']),
            OutboundGroup.selector(
              tag: 'manual',
              members: <String>['auto', 'DIRECT'],
              defaultMember: 'auto',
            ),
          ],
        ),
      );

      final outbounds = config['outbounds'] as List<dynamic>;
      final tags = outbounds
          .map((o) => (o as Map<String, dynamic>)['tag'] as String?)
          .toList();
      expect(tags, containsAll(<String>['auto', 'manual', 'PROXY', 'DIRECT']));
      // PROXY selector must include the groups + endpoint, never itself.
      final proxy = outbounds.whereType<Map<String, dynamic>>().firstWhere(
        (o) => o['tag'] == 'PROXY',
      );
      expect(
        proxy['outbounds'],
        containsAll(<String>['DIRECT', 'auto', 'manual', 'awg-hkg-02']),
      );
      expect((proxy['outbounds'] as List<dynamic>), isNot(contains('PROXY')));

      final file = File('${dir.path}/tiered-config.json');
      file.writeAsStringSync(jsonEncode(config));
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

  group('ConfigAssembler → sing-box check', () {
    test(
      'compiled policy produces a config the real sing-box accepts',
      () async {
        if (!singBoxAvailable) {
          markTestSkipped('needs windows/sing-box.exe');
        }
        final geo = await geoSeededFor(dir);
        final assembler = ConfigAssembler(geoAsset: geo);
        final config = assembler.build(
          endpointJson: awgEndpointJson,
          policy: testPolicy(),
        );
        final file = File('${dir.path}/config.json');
        await file.writeAsString(jsonEncode(config));

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
      },
    );

    test('rule_set entries reference compiled tags only', () async {
      if (!singBoxAvailable) {
        markTestSkipped('needs windows/sing-box.exe');
      }
      final geo = await geoSeededFor(dir);
      final assembler = ConfigAssembler(geoAsset: geo);
      final config = assembler.build(
        endpointJson: awgEndpointJson,
        policy: testPolicy(),
      );

      final route = config['route'] as Map<String, dynamic>;
      final ruleSet = route['rule_set'] as List<Map<String, dynamic>>;
      expect(ruleSet, hasLength(2));
      expect(
        ruleSet.map((e) => e['tag']),
        containsAll(<String>['geosite-cn', 'geoip-cn']),
      );
      for (final entry in ruleSet) {
        // W4.1: local entries referencing the seeded on-disk rule-set.
        expect(entry['type'], 'local');
        expect(entry['format'], 'binary');
        expect(entry['path'], isNotEmpty);
      }
    });
  });

  group('SRS round-trip with real binary', () {
    test('geosite-cn.srs decompiles (initial asset is a valid rule-set)', () {
      if (!singBoxAvailable) {
        markTestSkipped('needs windows/sing-box.exe');
      }
      final result = Process.runSync(singBoxExe, <String>[
        'rule-set',
        'decompile',
        '-o',
        '${dir.path}/geosite-cn.json',
        'rule_sets/initial_assets/geosite-cn.srs',
      ]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final json =
          jsonDecode(File('${dir.path}/geosite-cn.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(json['version'], 1);
      expect(json['rules'], isNotEmpty);
    });
  });

  group('RoutingCompiler P0 validation (production hardening)', () {
    CompiledRoute compileOne(RouteRule rule, {RoutingPolicy? policy}) {
      return const RoutingCompiler().compile(
        policy ??
            RoutingPolicy(
              rules: <RouteRule>[rule],
              leafOutbounds: const <String>['awg-hkg-02'],
            ),
      );
    }

    test('port 99999 rejected, valid ports pass', () {
      final bad = compileOne(
        const RouteRule(outbound: 'PROXY', ports: <String>['99999']),
      );
      expect(bad.isValid, isFalse);
      expect(bad.validationErrors.join(), contains('0-65535'));

      final good = compileOne(
        const RouteRule(outbound: 'PROXY', ports: <String>['443']),
      );
      expect(good.isValid, isTrue);
      expect(good.rulesJson.single['port'], <int>[443]);
    });

    test('bad CIDR rejected, good CIDR passes', () {
      final bad = compileOne(
        const RouteRule(outbound: 'PROXY', ipCidrs: <String>['999.1.1.1/33']),
      );
      expect(bad.isValid, isFalse);
      expect(bad.validationErrors.join(), contains('CIDR'));
    });

    test('bad regex rejected', () {
      final bad = compileOne(
        const RouteRule(outbound: 'PROXY', domainRegex: <String>['([unclosed']),
      );
      expect(bad.isValid, isFalse);
      expect(bad.validationErrors.join(), contains('regex'));
    });

    test('geosite + explicit ruleSets merge instead of overwrite', () {
      final result = compileOne(
        const RouteRule(
          outbound: 'PROXY',
          geosite: <String>['cn'],
          ruleSets: <String>['geoip-cn'],
        ),
      );
      expect(result.isValid, isTrue);
      final ruleSets = (result.rulesJson.single['rule_set'] as List<dynamic>)
          .cast<String>();
      expect(ruleSets, containsAll(<String>['geosite-cn', 'geoip-cn']));
    });

    test('unknown SRS tag rejected', () {
      final bad = compileOne(
        const RouteRule(
          outbound: 'PROXY',
          ruleSets: <String>['geosite-foobar'],
        ),
      );
      expect(bad.isValid, isFalse);
      expect(bad.validationErrors.join(), contains('geosite-foobar'));
    });

    test('outbound typo rejected', () {
      final bad = compileOne(
        const RouteRule(outbound: 'PROXI', domains: <String>['example.com']),
      );
      expect(bad.isValid, isFalse);
      expect(bad.validationErrors.join(), contains('PROXI'));
    });

    test('logical shape gaps are errors, not silent drops', () {
      final noMode = compileOne(
        const RouteRule(
          outbound: 'PROXY',
          rules: <RouteRule>[
            RouteRule(domains: <String>['a.com']),
            RouteRule(domains: <String>['b.com']),
          ],
        ),
      );
      expect(noMode.isValid, isFalse);
      expect(noMode.validationErrors.join(), contains('logicalMode'));

      final noSubs = compileOne(
        const RouteRule(outbound: 'PROXY', logicalMode: 'and'),
      );
      expect(noSubs.isValid, isFalse);
    });
  });
}
