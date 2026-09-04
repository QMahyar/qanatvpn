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
    SshEndpoint() => _ssh(endpoint),
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
      echEnabled: e.echEnabled,
      echConfig: e.echConfig,
    ),
    'transport': ?_resolveTransport(
      network: e.network,
      transport: e.transport,
      wsPath: e.wsPath,
      wsHost: e.wsHost,
    ),
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
  'transport': ?_resolveTransport(
    network: e.network,
    transport: e.transport,
    wsPath: e.wsPath,
  ),
};

/// Transport resolution shared by vless/vmess/trojan: the typed
/// [TransportOptions] wins when present; otherwise fall back to the legacy
/// flat ws fields (URI-imported ws links store there). Null → no transport
/// key at all (a bare `transport` with unknown type FATALs).
Map<String, dynamic>? _resolveTransport({
  required String? network,
  TransportOptions? transport,
  String? wsPath,
  String? wsHost,
}) {
  if (transport != null) {
    return _transport(transport);
  }
  if (wsPath != null || wsHost != null) {
    return _ws(wsPath, wsHost);
  }
  if (network == 'ws') {
    return _ws(null, null);
  }
  // grpc/httpupgrade/xhttp links whose transport detail was lost upstream:
  // type-only block still parses.
  if (network != null && network != 'ws') {
    return _transport(TransportOptions(type: network));
  }
  return null;
}

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
  'transport': ?_resolveTransport(network: e.network, transport: e.transport),
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
  bool echEnabled = false,
  String? echConfig,
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
    // ECH coexists with utls (probed). No config → engine fetches ECH
    // configs from DNS HTTPS records. NEVER emit the removed legacy fields
    // pq_signature_schemes_enabled / dynamic_record_sizing_disabled (init
    // FATAL on the 1.14 fork).
    if (echEnabled)
      'ech': <String, dynamic>{
        'enabled': true,
        'config': ?(echConfig == null || echConfig.isEmpty
            ? null
            : <String>[echConfig]),
      },
  };
}

Map<String, dynamic> _ws(String? path, String? host) => <String, dynamic>{
  'type': 'ws',
  'path': ?path,
  'headers': ?(host == null ? null : <String, dynamic>{'Host': host}),
};

Map<String, dynamic> _ssh(SshEndpoint e) => <String, dynamic>{
  // Outbound-only (endpoints[] rejects ssh, probed). Embedded key wins over
  // key path engine-side; we never emit private_key_path (Windows installed
  // apps cannot resolve arbitrary file paths reliably).
  'type': 'ssh',
  'tag': e.tag,
  'server': e.address,
  'server_port': e.port,
  if (e.user.isNotEmpty && e.user != 'root') 'user': e.user,
  if (e.password != null) 'password': e.password,
  if (e.privateKey != null) 'private_key': e.privateKey,
  if (e.privateKeyPassphrase != null)
    'private_key_passphrase': e.privateKeyPassphrase,
  if (e.hostKey != null && e.hostKey!.isNotEmpty) 'host_key': e.hostKey,
};

/// Builds the `transport` block per fork-accepted shapes
/// (go/amnezia-box/option/v2ray_transport.go). Field whitelist is strict:
/// unknown fields FATAL the strict JSON decoder. Probe-verified traps:
/// - xhttp: `x_padding_bytes` has NO omitempty in the fork struct and a
///   zero Range FATALs `x_padding_bytes cannot be disabled` — MUST always
///   emit it, including inside a download sub-block. `headers` must not
///   contain a host key (any case).
/// - grpc: no method/path/host fields exist.
/// - httpupgrade: host is a single string; no method/timeout fields.
/// - http: host is a Listable array (1-element here).
Map<String, dynamic>? _transport(TransportOptions? t) {
  if (t == null) {
    return null;
  }
  final cleanHeaders = <String, String>{
    for (final entry in (t.headers ?? const <String, String>{}).entries)
      if (entry.key.toLowerCase() != 'host') entry.key: entry.value,
  };
  return switch (t.type) {
    'ws' => <String, dynamic>{
      'type': 'ws',
      'path': ?t.path,
      'headers': ?(cleanHeaders.isEmpty
          ? null
          : Map<String, dynamic>.from(cleanHeaders)),
    },
    'grpc' => <String, dynamic>{
      'type': 'grpc',
      'service_name': ?t.serviceName,
      if (t.idleTimeoutSeconds != null)
        'idle_timeout': '${t.idleTimeoutSeconds}s',
      if (t.pingTimeoutSeconds != null)
        'ping_timeout': '${t.pingTimeoutSeconds}s',
    },
    'httpupgrade' => <String, dynamic>{
      'type': 'httpupgrade',
      'path': ?t.path,
      'host': ?t.host,
      'headers': ?(cleanHeaders.isEmpty
          ? null
          : Map<String, dynamic>.from(cleanHeaders)),
    },
    'xhttp' => <String, dynamic>{
      'type': 'xhttp',
      'path': ?t.path,
      'host': ?t.host,
      'mode': ?t.mode,
      // Fork struct has no omitempty on x_padding_bytes; absence decodes as
      // a zero Range and FATALs check. Xray emits 100-1000 by default.
      'x_padding_bytes': '100-1000',
      'headers': ?(cleanHeaders.isEmpty
          ? null
          : Map<String, dynamic>.from(cleanHeaders)),
    },
    'http' => <String, dynamic>{
      'type': 'http',
      'host': ?(t.host == null ? null : <String>[t.host!]),
      'path': ?t.path,
      'method': ?t.method,
      'headers': ?(cleanHeaders.isEmpty
          ? null
          : Map<String, dynamic>.from(cleanHeaders)),
      if (t.idleTimeoutSeconds != null)
        'idle_timeout': '${t.idleTimeoutSeconds}s',
      if (t.pingTimeoutSeconds != null)
        'ping_timeout': '${t.pingTimeoutSeconds}s',
    },
    // quic or unknown: type-only pass-through (least-lossy, still checkable).
    _ => <String, dynamic>{'type': t.type},
  };
}

/// Clash/URI `mport` uses `20000-30000` (dash); the fork's `server_ports`
/// uses sing-box port-range `min:max` (colon, same as route `port_range`).
/// Normalize per entry so an imported hop range never FATALs `check`.
List<String> _hy2Ports(String raw) => <String>[
  for (final part in raw.split(',')) part.trim().replaceAll('-', ':'),
];
