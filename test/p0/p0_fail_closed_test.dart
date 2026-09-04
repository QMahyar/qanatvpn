import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/core/network/http_cache.dart';
import 'package:yourvpn/modules/dns/dns_config.dart';
import 'package:yourvpn/modules/geo/geo_asset.dart';
import 'package:yourvpn/modules/routing/config_assembler.dart';
import 'package:yourvpn/modules/routing/routing_compiler.dart';
import 'package:yourvpn/modules/routing/routing_policy.dart';
import 'package:yourvpn/modules/sec/firewall.dart';

GeoAsset _geo(Directory dir) => GeoAsset(
  cacheDir: Directory('${dir.path}/cache'),
  initialDir: Directory('rule_sets/initial_assets'),
  http: HttpCache(
    fetch: (url, headers) async => throw const SocketException('offline'),
  ),
);

const _awg = '''
{"type":"awg","tag":"awg-hkg-02","private_key":"eCbtX5g5Pof3zH0Gu6dzulIzLB0B5xj+OhIfgVtWu1A=","address":["10.7.0.2/32"],"jc":5,"jmin":30,"jmax":1000,"s1":56,"s2":152,"h1":"1","h2":"2","h3":"3","h4":"4","peers":[{"address":"203.0.113.10","port":51820,"public_key":"7f3f0a5df0c497ef3f4a05c99a3a2d8d3c4b5a6e7f8091a2b3c4d5e6f708192a","allowed_ips":["0.0.0.0/0"],"persistent_keepalive_interval":25}]}
''';

void main() {
  test('assembler prepends kill-switch baseRules before user rules', () {
    final dir = Directory.systemTemp.createTempSync('p0asm');
    try {
      final asm = ConfigAssembler(geoAsset: _geo(dir));
      const policy = RoutingPolicy(
        rules: <RouteRule>[
          RouteRule(
            outbound: 'DIRECT',
            domainSuffixes: <String>['example.com'],
          ),
        ],
      );
      final cfg = asm.build(endpointJson: _awg, policy: policy);
      final rules = (cfg['route'] as Map)['rules'] as List;
      expect(rules.first['action'], 'hijack-dns');
      final violations = const FirewallPolicy().validateOrdering(rules);
      expect(violations, isEmpty, reason: violations.join('; '));
      // ::/0 + RFC1918 blocks present before the user rule.
      final hasV6 = rules.any(
        (r) =>
            r is Map &&
            (r['ip_cidr'] as List?)?.contains('::/0') == true &&
            r['outbound'] == 'BLOCK',
      );
      expect(hasV6, isTrue);
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test('TOR-CHAIN literal and sidecar tag both compile', () {
    const compiler = RoutingCompiler();
    const withDefault = RoutingPolicy(
      rules: <RouteRule>[
        RouteRule(outbound: 'TOR-CHAIN', domains: <String>['x.com']),
      ],
      torChain: TorChainOptions(),
    );
    final a = compiler.compile(withDefault);
    expect(a.isValid, isTrue, reason: a.validationErrors.join('; '));

    const withSidecar = RoutingPolicy(
      rules: <RouteRule>[
        RouteRule(outbound: 'tor-entry', domains: <String>['x.com']),
      ],
      torChain: TorChainOptions(),
    );
    final b = compiler.compile(withSidecar);
    expect(b.isValid, isTrue, reason: b.validationErrors.join('; '));
    expect(b.outboundsJson.any((o) => o['tag'] == 'tor-entry'), isTrue);
  });

  test('baseRulesScoped keeps LAN blocked even when allowLan=true', () {
    const open = FirewallPolicy(allowLan: true);
    const scoped = FirewallPolicy(allowLan: true);
    expect(
      open.baseRules().any(
        (r) => (r['ip_cidr'] as List?)?.contains('10.0.0.0/8') == true,
      ),
      isFalse,
    );
    expect(
      scoped.baseRulesScoped().any(
        (r) => (r['ip_cidr'] as List?)?.contains('10.0.0.0/8') == true,
      ),
      isTrue,
    );
  });

  test('dns filters stay Dart-side (fork has no fake_ip_filter schema)', () {
    final dir = Directory.systemTemp.createTempSync('p0dns');
    try {
      final json = const DnsConfig().toDnsJson(
        proxyTag: 'PROXY',
        geoAsset: _geo(dir),
      );
      final encoded = json.toString();
      expect(encoded.contains('fake_ip_filter'), isFalse);
      expect(encoded.contains('fake-ip-filter'), isFalse);
      // Ranges still ship.
      final fakeip =
          (json['servers'] as List).firstWhere(
                (s) => (s as Map)['tag'] == 'dns-fakeip',
              )
              as Map;
      expect(fakeip['inet4_range'], '198.18.0.0/15');
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
