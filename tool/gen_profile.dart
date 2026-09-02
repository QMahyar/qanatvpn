import 'dart:convert';
import 'dart:io';

import 'package:yourvpn/core/network/http_cache.dart';
import 'package:yourvpn/modules/geo/geo_asset.dart';
import 'package:yourvpn/modules/routing/config_assembler.dart';
import 'package:yourvpn/modules/routing/routing_policy.dart';

const awgEndpoint = '''
{
  "type": "awg",
  "tag": "awg-hkg-02",
  "private_key": "eCbtX5g5Pof3zH0Gu6dzulIzLB0B5xj+OhIfgVtWu1A=",
  "address": ["10.7.0.2/32"],
  "mtu": 1408,
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

void main() {
  final geo = GeoAsset(
    cacheDir: Directory('profiles/cache'),
    initialDir: Directory('rule_sets/initial_assets'),
    http: HttpCache(
      fetch: (Uri url, Map<String, String> headers) async =>
          throw const SocketException('offline'),
    ),
  );
  final assembler = ConfigAssembler(geoAsset: geo);
  final config = assembler.build(
    endpointJson: awgEndpoint,
    policy: const RoutingPolicy(
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
      ],
    ),
  );
  Directory('profiles').createSync(recursive: true);
  final encoder = const JsonEncoder.withIndent('  ');
  File('profiles/config.wg-awg.json').writeAsStringSync(
    '${encoder.convert(config)}\n',
  );
  stdout.writeln('written profiles/config.wg-awg.json');
}
