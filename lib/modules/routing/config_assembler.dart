import 'dart:convert';

import '../dns/dns_config.dart';
import '../geo/geo_asset.dart';
import 'routing_compiler.dart';
import 'routing_policy.dart';

/// Thin assembly step: a compiled [CompiledRoute] + [GeoAsset] tags + the
/// [DnsConfig] become a complete sing-box config document. No validation
/// logic lives here — that is the compiler's job; this only shapes the
/// envelope.
class ConfigAssembler {
  const ConfigAssembler({
    required this.geoAsset,
    this.compiler = const RoutingCompiler(),
    this.dns = const DnsConfig(),
  });

  final GeoAsset geoAsset;
  final RoutingCompiler compiler;
  final DnsConfig dns;

  /// Builds the full config JSON for a WG/AWG-first tunnel. An `awg` (or any
  /// endpoint-typed) payload goes into `route.endpoints`; protocol outbounds
  /// go into `outbounds`.
  Map<String, dynamic> build({
    required String endpointJson,
    required RoutingPolicy policy,
    String tag = 'tun-in',
    String defaultOutbound = 'PROXY',
  }) {
    final compiled = compiler.compile(policy);
    // DNS rules always reference geosite-cn, so guarantee its entry.
    final tags = <String>{'geosite-cn', ...compiled.ruleSetTags};
    final ruleSetEntries = <Map<String, dynamic>>[
      for (final t in tags)
        ...geoAsset.ruleSetEntriesFor(t, downloadDetour: defaultOutbound),
    ];
    final payload = jsonDecode(endpointJson) as Map<String, dynamic>;
    final isEndpoint = payload['type'] == 'awg' || payload['type'] == 'wireguard';
    final dnsJson = dns.toDnsJson(proxyTag: defaultOutbound, geoAsset: geoAsset);
    // Selector must list a member (real check FATALs on empty selector) and
    // DIRECT must exist so rules/detours resolve at runtime start.
    return <String, dynamic>{
      'log': <String, dynamic>{'level': 'info'},
      'dns': dnsJson,
      'inbounds': <dynamic>[
        <String, dynamic>{
          'type': 'tun',
          'tag': tag,
          'address': <String>[
            '172.19.0.1/30',
            'fdfe:dcba:9876::1/126',
            // FakeIP pool served to clients under TUN.
            dns.fakeIpRange,
          ],
          'auto_route': true,
          'strict_route': true,
        },
      ],
      'outbounds': <dynamic>[
        <String, dynamic>{
          'type': 'selector',
          'tag': defaultOutbound,
          'outbounds': <String>['DIRECT'],
        },
        <String, dynamic>{'type': 'direct', 'tag': 'DIRECT'},
      ],
      if (isEndpoint) 'endpoints': <dynamic>[payload],
      'route': <String, dynamic>{
        'auto_detect_interface': true,
        'final': defaultOutbound,
        'default_domain_resolver': <String, dynamic>{
          'server': 'dns-local',
        },
        if (ruleSetEntries.isNotEmpty) 'rule_set': ruleSetEntries,
        'rules': <dynamic>[...dns.hijackRules(), ...compiled.rulesJson],
      },
    };
  }
}
