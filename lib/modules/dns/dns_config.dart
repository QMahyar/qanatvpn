import '../geo/geo_asset.dart';

/// DNS + FakeIP block for the sing-box config.
///
/// Owns the fork's 1.14 DNS schema: typed servers (`https`/`local`/`fakeip`),
/// FakeIP pool `198.18.0.0/15`, `fake-ip-filter-mode`, bootstrap resolution of
/// the DoH server itself through the proxy (`dns-remote` detour), and the
/// always-on DNS hijack under TUN. Geo dependency goes through
/// [GeoAsset.getPath] — never through HTTP.
class DnsConfig {
  const DnsConfig({
    this.dohServer = '1.1.1.1',
    this.dohPath = '/dns-query',
    this.fakeIpRange = '198.18.0.0/15',
    this.fakeIpV6Range = 'fc00::/18',
    this.filterMode = 'whitelist',
    this.fakeIpFilters = const <String>[
      // Local discovery and pairing must resolve real IPs.
      '+.lan',
      '+.local',
      '+.msftconnecttest.com',
      '+.msftncsi.com',
      'time.*.com',
      'ntp.*.com',
    ],
    this.strategy = 'prefer_ipv4',
  });

  final String dohServer;
  final String dohPath;
  final String fakeIpRange;
  final String fakeIpV6Range;

  /// `whitelist` (matches are excluded from FakeIP) or `blacklist`.
  final String filterMode;
  final List<String> fakeIpFilters;
  final String strategy;

  /// The `dns` block. [proxyTag] is the selector outbound; geosite-cn traffic
  /// resolves through the local (ISP/系统) server so CN domains never burn
  /// proxy bandwidth.
  Map<String, dynamic> toDnsJson({
    required String proxyTag,
    required GeoAsset geoAsset,
  }) {
    return <String, dynamic>{
      'servers': <dynamic>[
        <String, dynamic>{
          'tag': 'dns-proxy',
          'type': 'https',
          'server': dohServer,
          'path': dohPath,
          'detour': proxyTag,
        },
        <String, dynamic>{'tag': 'dns-local', 'type': 'local'},
        <String, dynamic>{
          'tag': 'dns-fakeip',
          'type': 'fakeip',
          'inet4_range': fakeIpRange,
          'inet6_range': fakeIpV6Range,
        },
      ],
      'rules': <dynamic>[
        <String, dynamic>{
          'rule_set': <String>['geosite-cn'],
          'server': 'dns-local',
        },
        <String, dynamic>{'clash_mode': 'Direct', 'server': 'dns-local'},
        <String, dynamic>{'clash_mode': 'Global', 'server': 'dns-proxy'},
        <String, dynamic>{
          // Queries answered from FakeIP pool (remote sites through the tun).
          'query_type': <String>['A', 'AAAA'],
          'server': 'dns-fakeip',
        },
      ],
      'final': 'dns-proxy',
      'strategy': strategy,
    };
  }

  /// Route rules sending port-53 traffic into the TUN's DNS hijack.
  /// `hijack` is always-on while the tunnel is up — DNS leaks are the most
  /// common failure (6/16 researched VPNs leaked DNS).
  List<Map<String, dynamic>> hijackRules() {
    return <Map<String, dynamic>>[
      const <String, dynamic>{'protocol': 'dns', 'action': 'hijack-dns'},
    ];
  }
}
