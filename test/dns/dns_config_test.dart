import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yourvpn/core/network/http_cache.dart';
import 'package:yourvpn/modules/dns/dns_config.dart';
import 'package:yourvpn/modules/geo/geo_asset.dart';
import 'package:yourvpn/modules/routing/config_assembler.dart';
import 'package:yourvpn/modules/routing/routing_policy.dart';

final String singBoxExe = p.join(
  Directory.current.path,
  'windows',
  'sing-box.exe',
);

GeoAsset geoFor(Directory dir) {
  return GeoAsset(
    cacheDir: Directory('${dir.path}/cache'),
    initialDir: Directory('rule_sets/initial_assets'),
    http: HttpCache(
      fetch: (Uri url, Map<String, String> headers) async =>
          throw const SocketException('offline'),
    ),
  );
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('dns_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('dns block shape: typed servers + fakeip server + rules', () {
    final geo = geoFor(dir);
    final json = const DnsConfig().toDnsJson(proxyTag: 'PROXY', geoAsset: geo);

    final servers = (json['servers'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(servers, hasLength(3));
    expect(servers[0]['type'], 'https');
    expect(servers[0]['server'], '1.1.1.1');
    expect(servers[0]['detour'], 'PROXY');
    expect(servers[1]['type'], 'local');
    expect(servers[2]['type'], 'fakeip');
    expect(servers[2]['inet4_range'], '198.18.0.0/15');
    expect(servers[2]['inet6_range'], 'fc00::/18');

    final rules = (json['rules'] as List<dynamic>).cast<Map<String, dynamic>>();
    final geositeRule = rules.firstWhere((r) => r.containsKey('rule_set'));
    expect(geositeRule['server'], 'dns-local');
    expect(geositeRule['rule_set'], contains('geosite-cn'));

    expect(json['final'], 'dns-proxy');
    expect(json['strategy'], 'prefer_ipv4');
    expect(
      json.containsKey('fakeip'),
      isFalse,
      reason: 'legacy dns.fakeip removed in 1.14',
    );
  });

  test('hijack rules: protocol dns → hijack-dns, always first', () {
    final rules = const DnsConfig().hijackRules();
    expect(rules.single['protocol'], 'dns');
    expect(rules.single['action'], 'hijack-dns');
  });

  test('fake-ip filters exclude lan + ntp from the pool', () {
    final config = const DnsConfig();
    expect(config.fakeIpFilters, contains('+.lan'));
    expect(config.fakeIpFilters, contains('+.local'));
  });

  test('full config with DNS + FakeIP passes real sing-box check', () async {
    if (!File(singBoxExe).existsSync()) {
      markTestSkipped('needs windows/sing-box.exe');
    }
    // W4.1: seed the local rule-set files the same way startup does.
    final geo = geoFor(dir);
    for (final tag in GeoAsset.registry.keys) {
      await geo.ensure(tag);
    }
    final assembler = ConfigAssembler(geoAsset: geo);
    final config = assembler.build(
      endpointJson:
          '{"type":"awg","tag":"awg-t","private_key":"eCbtX5g5Pof3zH0Gu6dzulIzLB0B5xj+OhIfgVtWu1A=","address":["10.7.0.2/32"],"jc":5,"jmin":30,"jmax":1000,"s1":56,"s2":152,"h1":"1","h2":"2","h3":"3","h4":"4","peers":[{"address":"203.0.113.10","port":51820,"public_key":"7f3f0a5df0c497ef3f4a05c99a3a2d8d3c4b5a6e7f8091a2b3c4d5e6f708192a","allowed_ips":["0.0.0.0/0"]}]}',
      policy: const RoutingPolicy(rules: <RouteRule>[]),
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

    final route = config['route'] as Map<String, dynamic>;
    final rules = route['rules'] as List<dynamic>;
    expect(
      (rules.first as Map<String, dynamic>)['action'],
      'hijack-dns',
      reason: 'DNS hijack must be the first rule',
    );
    final dns = config['dns'] as Map<String, dynamic>;
    final servers = dns['servers'] as List<dynamic>;
    expect(
      servers.any((s) => (s as Map<String, dynamic>)['type'] == 'fakeip'),
      isTrue,
    );
  });

  test('fakeip pool is inside tun address so clients can route it', () {
    final geo = geoFor(dir);
    final assembler = ConfigAssembler(geoAsset: geo);
    final config = assembler.build(
      endpointJson:
          '{"type":"awg","tag":"awg-t","private_key":"eCbtX5g5Pof3zH0Gu6dzulIzLB0B5xj+OhIfgVtWu1A=","address":["10.7.0.2/32"],"peers":[]}',
      policy: const RoutingPolicy(rules: <RouteRule>[]),
    );
    final inbound =
        (config['inbounds'] as List<dynamic>).first as Map<String, dynamic>;
    final addresses = inbound['address'] as List<String>;
    expect(addresses, contains('198.18.0.0/15'));
  });
}
