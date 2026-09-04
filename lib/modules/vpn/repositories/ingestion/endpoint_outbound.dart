import 'normalized_endpoint.dart';

/// NormalizedEndpoint → sing-box `outbounds[]` entry, one function per
/// sealed-union variant. Shapes verified against the fork with real
/// `sing-box check` (probe session 8g):
/// - tuic ALPN lives under `tls.alpn` (top-level `alpn` FATALs).
/// - vmess tls/transport are siblings of the vmess fields.
/// - reality needs a base64url 32-byte public_key; utls fingerprint goes
///   under tls.utls.
/// WG/AWG endpoints go through AwgConfig/WG handling (endpoints[], not
/// outbounds[]) — see awg_config.dart; this file covers the 6 proxy
/// protocols.
Map<String, dynamic> endpointToOutboundJson(NormalizedEndpoint endpoint) {
  return switch (endpoint) {
    VlessEndpoint() => _vless(endpoint),
    VmessEndpoint() => _vmess(endpoint),
    ShadowsocksEndpoint() => _shadowsocks(endpoint),
    TrojanEndpoint() => _trojan(endpoint),
    Hysteria2Endpoint() => _hysteria2(endpoint),
    TuicEndpoint() => _tuic(endpoint),
    WireGuardEndpoint() => throw ArgumentError(
      'WireGuard/AWG endpoints use AwgConfig.toEndpointJson (endpoints[])',
    ),
  };
}

Map<String, dynamic> _vless(VlessEndpoint e) {
  // Reality without uTLS FATALs the fork at start (probed engine truth).
  // Default to chrome so an imported pbk/sid link never ships a dead
  // profile; the user can still override fp explicitly.
  final fingerprint =
      e.fingerprint ?? (e.realityPublicKey != null ? 'chrome' : null);
  return <String, dynamic>{
    'type': 'vless',
    'tag': e.tag,
    'server': e.address,
    'server_port': e.port,
    'uuid': e.uuid,
    if (e.flow != null) 'flow': e.flow,
    'tls': _tls(
      enabled: true,
      serverName: e.sni ?? e.address,
      utlsFingerprint: fingerprint,
      realityPublicKey: e.realityPublicKey,
      realityShortId: e.realityShortId,
    ),
    if (e.network == 'ws') 'transport': _ws(e.wsPath, e.wsHost),
  };
}

Map<String, dynamic> _vmess(VmessEndpoint e) => <String, dynamic>{
  'type': 'vmess',
  'tag': e.tag,
  'server': e.address,
  'server_port': e.port,
  'uuid': e.uuid,
  'security': e.security,
  'alter_id': e.alterId,
  if (e.tls == 'tls' || e.tls == 'reality')
    'tls': _tls(enabled: true, serverName: e.sni ?? e.address),
  if (e.network == 'ws') 'transport': _ws(e.wsPath, null),
};

Map<String, dynamic> _shadowsocks(ShadowsocksEndpoint e) => <String, dynamic>{
  'type': 'shadowsocks',
  'tag': e.tag,
  'server': e.address,
  'server_port': e.port,
  'method': e.method,
  'password': e.password,
  if (e.plugin != null) 'plugin': e.plugin,
  if (e.pluginOpts != null)
    'plugin_opts': e.pluginOpts!.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(';'),
};

Map<String, dynamic> _trojan(TrojanEndpoint e) => <String, dynamic>{
  'type': 'trojan',
  'tag': e.tag,
  'server': e.address,
  'server_port': e.port,
  'password': e.password,
  'tls': _tls(
    enabled: true,
    serverName: e.sni ?? e.address,
    insecure: e.allowInsecure,
  ),
  if (e.network == 'ws') 'transport': <String, dynamic>{'type': 'ws'},
};

Map<String, dynamic> _hysteria2(Hysteria2Endpoint e) => <String, dynamic>{
  'type': 'hysteria2',
  'tag': e.tag,
  'server': e.address,
  'server_port': e.port,
  'password': e.auth,
  if (e.ports != null) 'server_ports': _hy2Ports(e.ports!),
  if (e.hopIntervalSeconds != null) 'hop_interval': '${e.hopIntervalSeconds}s',
  if (e.upMbps != null) 'up_mbps': e.upMbps,
  if (e.downMbps != null) 'down_mbps': e.downMbps,
  if (e.obfsPassword != null)
    'obfs': <String, dynamic>{'type': 'salamander', 'password': e.obfsPassword},
  'tls': _tls(
    enabled: true,
    serverName: e.sni ?? e.address,
    insecure: e.insecure,
    alpn: const <String>['h3'],
  ),
};

Map<String, dynamic> _tuic(TuicEndpoint e) => <String, dynamic>{
  'type': 'tuic',
  'tag': e.tag,
  'server': e.address,
  'server_port': e.port,
  'uuid': e.uuid,
  'password': e.password,
  if (e.congestionControl != null) 'congestion_control': e.congestionControl,
  if (e.udpRelayMode != null) 'udp_relay_mode': e.udpRelayMode,
  'tls': _tls(enabled: true, serverName: e.sni ?? e.address, alpn: e.alpn),
};

Map<String, dynamic> _tls({
  required bool enabled,
  required String serverName,
  String? utlsFingerprint,
  String? realityPublicKey,
  String? realityShortId,
  bool insecure = false,
  List<String>? alpn,
}) {
  return <String, dynamic>{
    'enabled': enabled,
    'server_name': serverName,
    if (insecure) 'insecure': true,
    'alpn': ?alpn,
    if (utlsFingerprint != null)
      'utls': <String, dynamic>{
        'enabled': true,
        'fingerprint': utlsFingerprint,
      },
    if (realityPublicKey != null)
      'reality': <String, dynamic>{
        'enabled': true,
        'public_key': realityPublicKey,
        'short_id': ?realityShortId,
      },
  };
}

Map<String, dynamic> _ws(String? path, String? host) => <String, dynamic>{
  'type': 'ws',
  'path': ?path,
  'headers': ?(host == null ? null : <String, dynamic>{'Host': host}),
};

/// Clash/URI `mport` uses `20000-30000` (dash); the fork's `server_ports`
/// uses sing-box port-range `min:max` (colon, same as route `port_range`).
/// Normalize per entry so an imported hop range never FATALs `check`.
List<String> _hy2Ports(String raw) => <String>[
  for (final part in raw.split(',')) part.trim().replaceAll('-', ':'),
];
