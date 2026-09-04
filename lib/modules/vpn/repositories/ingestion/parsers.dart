import 'dart:convert';

import 'package:yaml/yaml.dart';

import 'normalized_endpoint.dart';

/// Shared URL/percentage-decoding helpers for the URI-family parsers.

Uri parseShareUri(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('empty share link');
  }
  return Uri.parse(trimmed);
}

Map<String, String> queryOf(Uri uri) {
  return <String, String>{
    for (final entry in uri.queryParameters.entries) entry.key: entry.value,
  };
}

String requireQuery(Map<String, String> query, String key, String what) {
  final value = query[key];
  if (value == null || value.isEmpty) {
    throw FormatException('missing $key in $what');
  }
  return value;
}

int intOf(String source, String what) {
  final value = int.tryParse(source);
  if (value == null) {
    throw FormatException('bad number in $what: $source');
  }
  return value;
}

/// Coerces a YAML/JSON scalar to int, FormatException on any failure
/// (floats, bools, null) so malformed subscriptions never escape as TypeError.
int intField(Object? value, String what) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return intOf(value, what);
  }
  throw FormatException('bad integer in $what: $value');
}

/// Coerces to non-null String, FormatException when missing.
String stringField(Object? value, String what) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('missing $what');
}

bool boolOf(String? source) =>
    source != null && (source == '1' || source.toLowerCase() == 'true');

/// Standard base64 first (real-world links use `+/`), URL-safe fallback.
/// [base64Url.decode] rejects the standard alphabet, which breaks real
/// v2rayN payloads. Never recurses: both alphabets are tried iteratively and
/// a doubly-malformed payload throws FormatException instead of overflowing
/// the stack and crashing the ingestion isolate.
String decodeBase64Flex(String source) {
  final normalized = source.trim().replaceAll('\n', '');
  try {
    return utf8.decode(base64.decode(base64.normalize(normalized)));
  } on FormatException {
    // Fall through to the URL-safe alphabet with padding restored.
  }
  var padded = normalized.replaceAll('-', '+').replaceAll('_', '/');
  final remainder = padded.length % 4;
  if (remainder == 1) {
    throw FormatException('invalid base64 payload: $source');
  }
  if (remainder != 0) {
    padded = padded + ('=' * (4 - remainder));
  }
  return utf8.decode(base64.decode(base64.normalize(padded)));
}

/// YAML fields accept either a scalar or a list.
List<String> stringList(Object? value) {
  if (value == null) {
    return const <String>[];
  }
  if (value is String) {
    return <String>[value];
  }
  if (value is YamlList) {
    return value.map((e) => e.toString()).toList();
  }
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  }
  return <String>[value.toString()];
}

/// clash yaml `proxies:` + `listeners:` entries.
class ClashYamlParser {
  List<NormalizedEndpoint> parse(String source) {
    YamlDocument yamlDoc;
    try {
      yamlDoc = loadYamlDocument(source);
    } on YamlException catch (e) {
      throw FormatException('clash: invalid yaml: ${e.message}');
    }
    final doc = yamlDoc.contents;
    if (doc is! YamlMap) {
      throw const FormatException('clash: not a yaml mapping');
    }
    final endpoints = <NormalizedEndpoint>[];
    final proxies = doc['proxies'];
    if (proxies is YamlList) {
      for (final node in proxies) {
        if (node is YamlMap) {
          endpoints.add(_proxy(node));
        }
      }
    }
    final listeners = doc['listeners'];
    if (listeners is YamlList) {
      for (final node in listeners) {
        if (node is YamlMap && node['type'] == 'mixed') {
          // Clash `listeners: [{type: mixed}]` is a LOCAL inbound (a socks/
          // http port on the device), not a proxy. Mapping it to any
          // endpoint variant would ship a useless dial to 127.0.0.1 into
          // the engine config — skipped outright.
          continue;
        }
      }
    }
    return endpoints;
  }

  NormalizedEndpoint _proxy(YamlMap node) {
    final type = (node['type'] as String? ?? '').toLowerCase();
    final name = node['name'] as String? ?? 'clash';
    switch (type) {
      case 'vless':
        return VlessEndpoint(
          tag: name,
          address: stringField(node['server'], 'clash server'),
          port: intField(node['port'], 'clash port'),
          uuid: stringField(node['uuid'], 'clash uuid'),
          flow: node['flow'] as String?,
          network: node['network'] as String?,
          security: (node['tls'] as bool? ?? false) ? 'tls' : null,
          sni: node['servername'] as String?,
        );
      case 'vmess':
        return VmessEndpoint(
          tag: name,
          address: stringField(node['server'], 'clash server'),
          port: intField(node['port'], 'clash port'),
          uuid: stringField(node['uuid'], 'clash uuid'),
          security: node['cipher'] as String? ?? 'auto',
          alterId: node['alterId'] == null
              ? 0
              : intField(node['alterId'], 'alterId'),
          network: node['network'] as String?,
          tls: (node['tls'] as bool? ?? false) ? 'tls' : null,
          sni: node['servername'] as String?,
          wsPath: (node['ws-opts'] as YamlMap?)?['path'] as String?,
        );
      case 'ss':
        return ShadowsocksEndpoint(
          tag: name,
          address: stringField(node['server'], 'clash server'),
          port: intField(node['port'], 'clash port'),
          method: stringField(node['cipher'], 'clash cipher'),
          password: stringField(node['password'], 'clash password'),
          plugin: node['plugin'] as String?,
        );
      case 'trojan':
        return TrojanEndpoint(
          tag: name,
          address: stringField(node['server'], 'clash server'),
          port: intField(node['port'], 'clash port'),
          password: stringField(node['password'], 'clash password'),
          sni: node['sni'] as String?,
          network: node['network'] as String?,
          allowInsecure: node['skip-cert-verify'] as bool? ?? false,
        );
      case 'hysteria2':
        final ports = node['ports'] as String?;
        return Hysteria2Endpoint(
          tag: name,
          address: stringField(node['server'], 'clash server'),
          port: node['port'] == null
              ? 443
              : intField(node['port'], 'clash port'),
          auth: node['password'] as String? ?? node['auth'] as String? ?? '',
          sni: node['sni'] as String?,
          obfsPassword: (node['obfs'] as YamlMap?)?['password'] as String?,
          upMbps: _asInt(node['up']),
          downMbps: _asInt(node['down']),
          ports: ports,
          hopIntervalSeconds: _asInt(node['hop-interval']),
          insecure: node['skip-cert-verify'] as bool? ?? false,
        );
      case 'tuic':
        return TuicEndpoint(
          tag: name,
          address: stringField(node['server'], 'clash server'),
          port: intField(node['port'], 'clash port'),
          uuid: stringField(node['uuid'], 'sing-box uuid'),
          password: node['password'] as String? ?? '',
          congestionControl: node['congestion-controller'] as String?,
          sni: node['sni'] as String?,
          udpRelayMode: node['udp-relay-mode'] as String?,
        );
      case 'wireguard':
        final peers = <WireGuardPeer>[];
        final peerNode = node['peers'];
        if (peerNode is YamlList) {
          for (final p in peerNode.whereType<YamlMap>()) {
            peers.add(
              WireGuardPeer(
                publicKey: p['public-key'] as String? ?? '',
                endpoint: '${p['server']}:${p['port']}',
                allowedIps: stringList(p['allowed-ips']),
                presharedKey: p['preshared-key'] as String?,
              ),
            );
          }
        }
        return WireGuardEndpoint(
          tag: name,
          privateKey: node['private-key'] as String? ?? '',
          addresses: stringList(node['ip'] ?? node['address']),
          peers: peers,
          mtu: node['mtu'] as int?,
          awg: _clashAmnezia(node),
        );
      default:
        throw FormatException('clash: unsupported type "$type"');
    }
  }

  AwgValues? _clashAmnezia(YamlMap node) {
    final amnezia = node['amnezia-wg-option'];
    if (amnezia is! YamlMap) {
      return null;
    }
    return AwgValues(
      jc: amnezia['jc'] as int?,
      jmin: amnezia['jmin'] as int?,
      jmax: amnezia['jmax'] as int?,
      s1: amnezia['s1'] as int?,
      s2: amnezia['s2'] as int?,
      s3: amnezia['s3'] as int?,
      s4: amnezia['s4'] as int?,
      h1: amnezia['h1']?.toString(),
      h2: amnezia['h2']?.toString(),
      h3: amnezia['h3']?.toString(),
      h4: amnezia['h4']?.toString(),
      i1: amnezia['i1']?.toString(),
      i2: amnezia['i2']?.toString(),
      i3: amnezia['i3']?.toString(),
      i4: amnezia['i4']?.toString(),
      i5: amnezia['i5']?.toString(),
      id: amnezia['id']?.toString(),
      ip: amnezia['ip']?.toString(),
      ib: amnezia['ib']?.toString(),
    );
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
    }
    return null;
  }
}

/// sing-box JSON `outbounds` / `endpoints` arrays.
class SingboxJsonParser {
  List<NormalizedEndpoint> parse(String source) {
    final doc = jsonDecode(source);
    if (doc is! Map<String, dynamic>) {
      throw const FormatException('sing-box: root not an object');
    }
    final endpoints = <NormalizedEndpoint>[];
    final outbounds = doc['outbounds'];
    if (outbounds is List<dynamic>) {
      for (final node in outbounds) {
        if (node is Map<String, dynamic>) {
          final parsed = _outbound(node);
          if (parsed != null) {
            endpoints.add(parsed);
          }
        }
      }
    }
    final awgEndpoints = doc['endpoints'];
    if (awgEndpoints is List<dynamic>) {
      for (final node in awgEndpoints) {
        if (node is Map<String, dynamic> && node['type'] == 'awg') {
          endpoints.add(_awgEndpoint(node));
        }
      }
    }
    return endpoints;
  }

  /// Transport detail capture shared by vless/vmess/trojan sing-box nodes:
  /// previously only type/path were read — grpc service_name, httpupgrade
  /// host, xhttp mode were all dropped, so an imported round-trip lost them.
  TransportOptions? _transport(Map<String, dynamic>? raw) {
    final type = raw?['type'] as String?;
    if (type == null) {
      return null;
    }
    return TransportOptions(
      type: type,
      path: raw!['path'] as String?,
      host: raw['host'] is String
          ? raw['host'] as String
          : (raw['host'] as List<dynamic>?)?.firstOrNull?.toString(),
      headers: raw['headers'] is Map
          ? <String, String>{
              for (final entry
                  in (raw['headers'] as Map<dynamic, dynamic>).entries)
                entry.key.toString(): entry.value.toString(),
            }
          : null,
      serviceName: raw['service_name'] as String?,
      mode: raw['mode'] as String?,
      idleTimeoutSeconds: _durationSeconds(raw['idle_timeout']),
      pingTimeoutSeconds: _durationSeconds(raw['ping_timeout']),
      method: raw['method'] as String?,
    );
  }

  /// Parses sing-box duration strings ('60s', '15m', '1h30m') to seconds.
  int? _durationSeconds(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is! String) {
      return null;
    }
    final match = RegExp(r'^(\d+h)?(\d+m)?(\d+s)?$').firstMatch(value);
    if (match == null) {
      return null;
    }
    final hours = int.tryParse(match.group(1)?.replaceAll('h', '') ?? '') ?? 0;
    final minutes =
        int.tryParse(match.group(2)?.replaceAll('m', '') ?? '') ?? 0;
    final seconds =
        int.tryParse(match.group(3)?.replaceAll('s', '') ?? '') ?? 0;
    return hours * 3600 + minutes * 60 + seconds;
  }

  NormalizedEndpoint? _outbound(Map<String, dynamic> node) {
    final type = node['type'] as String?;
    final tag = node['tag'] as String? ?? 'singbox';
    switch (type) {
      case 'vless':
        final tls = node['tls'] as Map<String, dynamic>?;
        final transport = node['transport'] as Map<String, dynamic>?;
        final reality = tls?['reality'] as Map<String, dynamic>?;
        final ech = tls?['ech'] as Map<String, dynamic>?;
        return VlessEndpoint(
          tag: tag,
          address: stringField(node['server'], 'sing-box server'),
          port: intField(node['server_port'], 'sing-box server_port'),
          uuid: stringField(node['uuid'], 'sing-box uuid'),
          flow: node['flow'] as String?,
          network: transport?['type'] as String?,
          security: tls?['enabled'] == true ? 'tls' : null,
          sni: tls?['server_name'] as String?,
          fingerprint: tls?['utls'] == null
              ? null
              : (tls!['utls'] as Map<String, dynamic>)['fingerprint']
                    as String?,
          realityPublicKey: reality?['public_key'] as String?,
          realityShortId: reality?['short_id'] as String?,
          wsPath: transport?['path'] as String?,
          wsHost:
              (transport?['headers'] as Map<String, dynamic>?)?['Host']
                  as String?,
          transport: _transport(transport),
          echEnabled: ech?['enabled'] == true,
          echConfig: (ech?['config'] as List<dynamic>?)?.firstOrNull as String?,
        );
      case 'vmess':
        final tls = node['tls'] as Map<String, dynamic>?;
        final transport = node['transport'] as Map<String, dynamic>?;
        return VmessEndpoint(
          tag: tag,
          address: stringField(node['server'], 'sing-box server'),
          port: intField(node['server_port'], 'sing-box server_port'),
          uuid: stringField(node['uuid'], 'sing-box uuid'),
          security: node['security'] as String? ?? 'auto',
          alterId: node['alter_id'] as int? ?? 0,
          network: transport?['type'] as String?,
          tls: tls?['enabled'] == true ? 'tls' : null,
          sni: tls?['server_name'] as String?,
          wsPath: transport?['path'] as String?,
          transport: _transport(transport),
        );
      case 'shadowsocks':
        final plugin = node['plugin'] as String?;
        final pluginOpts = node['plugin_opts'] as String?;
        return ShadowsocksEndpoint(
          tag: tag,
          address: stringField(node['server'], 'sing-box server'),
          port: intField(node['server_port'], 'sing-box server_port'),
          method: stringField(node['method'], 'sing-box method'),
          password: stringField(node['password'], 'sing-box password'),
          plugin: plugin,
          pluginOpts: pluginOpts == null ? null : _parsePluginOpts(pluginOpts),
        );
      case 'trojan':
        final tls = node['tls'] as Map<String, dynamic>?;
        final transport = node['transport'] as Map<String, dynamic>?;
        return TrojanEndpoint(
          tag: tag,
          address: stringField(node['server'], 'sing-box server'),
          port: intField(node['server_port'], 'sing-box server_port'),
          password: stringField(node['password'], 'sing-box password'),
          sni: tls?['server_name'] as String?,
          network: transport?['type'] as String?,
          allowInsecure: tls?['insecure'] == true,
          transport: _transport(transport),
        );
      case 'ssh':
        final hostKey = node['host_key'] is List
            ? List<String>.from(node['host_key'] as List<dynamic>)
            : null;
        return SshEndpoint(
          tag: tag,
          address: stringField(node['server'], 'sing-box server'),
          port: node['server_port'] == null
              ? 22
              : intField(node['server_port'], 'sing-box server_port'),
          user: node['user'] as String? ?? 'root',
          password: node['password'] as String?,
          privateKey: node['private_key'] is String
              ? node['private_key'] as String
              : (node['private_key'] as List<dynamic>?)?.join('\n'),
          privateKeyPassphrase: node['private_key_passphrase'] as String?,
          hostKey: hostKey,
        );
      case 'hysteria2':
        final tls = node['tls'] as Map<String, dynamic>?;
        return Hysteria2Endpoint(
          tag: tag,
          address: stringField(node['server'], 'sing-box server'),
          port: intField(node['server_port'], 'sing-box server_port'),
          auth: node['password'] as String? ?? node['auth'] as String? ?? '',
          sni: tls?['server_name'] as String?,
          obfsPassword:
              (node['obfs'] as Map<String, dynamic>?)?['password'] as String?,
          upMbps: node['up_mbps'] as int?,
          downMbps: node['down_mbps'] as int?,
          ports: node['server_ports'] as String?,
          hopIntervalSeconds: node['hop_interval'] is String
              ? int.tryParse(node['hop_interval'] as String)
              : node['hop_interval'] as int?,
          insecure: tls?['insecure'] == true,
        );
      case 'tuic':
        final tls = node['tls'] as Map<String, dynamic>?;
        return TuicEndpoint(
          tag: tag,
          address: stringField(node['server'], 'sing-box server'),
          port: intField(node['server_port'], 'sing-box server_port'),
          uuid: stringField(node['uuid'], 'sing-box uuid'),
          password: node['password'] as String? ?? '',
          congestionControl: node['congestion_control'] as String?,
          alpn: List<String>.from(
            tls?['alpn'] as List<dynamic>? ?? <String>['h3'],
          ),
          sni: tls?['server_name'] as String?,
          udpRelayMode: node['udp_relay_mode'] as String?,
        );
      default:
        // direct/block/dns/selector/urltest/chain are engine-internal.
        return null;
    }
  }

  WireGuardEndpoint _awgEndpoint(Map<String, dynamic> node) {
    final peers = <WireGuardPeer>[];
    final peerNodes = node['peers'];
    if (peerNodes is List<dynamic>) {
      for (final p in peerNodes.whereType<Map<String, dynamic>>()) {
        final address = p['address'] as String? ?? '';
        final port = p['port'] as int? ?? 0;
        peers.add(
          WireGuardPeer(
            publicKey: p['public_key'] as String? ?? '',
            endpoint: '$address:$port',
            allowedIps: List<String>.from(
              p['allowed_ips'] as List<dynamic>? ?? <String>[],
            ),
            presharedKey: p['preshared_key'] as String?,
            persistentKeepalive: _keepaliveInt(
              p['persistent_keepalive_interval'],
            ),
          ),
        );
      }
    }
    return WireGuardEndpoint(
      tag: node['tag'] as String? ?? 'awg',
      privateKey: node['private_key'] as String? ?? '',
      addresses: List<String>.from(
        node['address'] as List<dynamic>? ?? <String>[],
      ),
      mtu: node['mtu'] as int?,
      peers: peers,
      awg: AwgValues(
        jc: node['jc'] as int?,
        jmin: node['jmin'] as int?,
        jmax: node['jmax'] as int?,
        s1: node['s1'] as int?,
        s2: node['s2'] as int?,
        s3: node['s3'] as int?,
        s4: node['s4'] as int?,
        h1: node['h1']?.toString(),
        h2: node['h2']?.toString(),
        h3: node['h3']?.toString(),
        h4: node['h4']?.toString(),
        i1: node['i1']?.toString(),
        i2: node['i2']?.toString(),
        i3: node['i3']?.toString(),
        i4: node['i4']?.toString(),
        i5: node['i5']?.toString(),
      ),
    );
  }

  int? _keepaliveInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value.split('-').first);
    }
    return null;
  }

  Map<String, String> _parsePluginOpts(String source) {
    return <String, String>{
      for (final part in source.split(';'))
        if (part.contains('=')) ...<String, String>{
          part.substring(0, part.indexOf('=')): part.substring(
            part.indexOf('=') + 1,
          ),
        },
    };
  }
}

/// `ssh://user:password@host:port#tag` or `ssh://user@host:port#tag`.
/// Private keys cannot ride a share link — password auth only; key-based
/// nodes arrive via sing-box JSON import or manual entry.
class SshUriParser {
  List<NormalizedEndpoint> parse(String raw) {
    final uri = parseShareUri(raw);
    if (uri.scheme != 'ssh') {
      throw FormatException('not an ssh link: ${uri.scheme}');
    }
    final host = uri.host;
    if (host.isEmpty) {
      throw const FormatException('ssh: missing host');
    }
    final port = uri.port == 0 ? 22 : uri.port;
    final user = uri.userInfo.isEmpty ? 'root' : uri.userInfo.split(':').first;
    final password = uri.userInfo.contains(':')
        ? uri.userInfo.substring(uri.userInfo.indexOf(':') + 1)
        : null;
    final tag = uri.fragment.isNotEmpty
        ? Uri.decodeComponent(uri.fragment)
        : '$host:$port';
    return <NormalizedEndpoint>[
      SshEndpoint(
        tag: tag,
        address: host,
        port: port,
        user: user,
        password: password,
      ),
    ];
  }
}

/// `vless://uuid@host:port?params#tag` (Reality/Vision/XHTTP params).
class VlessUriParser {
  List<NormalizedEndpoint> parse(String raw) {
    final uri = parseShareUri(raw);
    if (uri.scheme != 'vless') {
      throw FormatException('not a vless link: ${uri.scheme}');
    }
    final query = queryOf(uri);
    final userInfo = uri.userInfo;
    final host = uri.host;
    final port = uri.port == 0 ? 443 : uri.port;
    final tag = uri.fragment.isNotEmpty
        ? Uri.decodeComponent(uri.fragment)
        : '$host:$port';
    return <NormalizedEndpoint>[
      VlessEndpoint(
        tag: tag,
        address: host,
        port: port,
        uuid: userInfo.isNotEmpty
            ? userInfo
            : requireQuery(query, 'id', 'vless'),
        flow: query['flow'],
        network: query['type'],
        security: query['security'],
        sni: query['sni'],
        fingerprint: query['fp'],
        realityPublicKey: query['pbk'],
        realityShortId: query['sid'],
        wsPath: query['path'],
        wsHost: query['host'],
        // XHTTP links (share:xhttp flavors) carry mode + padding params.
        transport: query['type'] == 'xhttp'
            ? TransportOptions(
                type: 'xhttp',
                path: query['path'],
                host: query['host'],
                mode: query['mode'],
              )
            : null,
        echEnabled: query['ech'] == '1' || query['ech'] == 'true',
      ),
    ];
  }
}

/// `vmess://base64(json)` (v2rayN flavor) with fallback to query form.
class VmessUriParser {
  List<NormalizedEndpoint> parse(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith('vmess://')) {
      throw FormatException('not a vmess link: $trimmed');
    }
    // No Uri.parse: the base64 payload sits in the host position and would
    // be lowercased.
    var body = trimmed.substring('vmess://'.length);
    final hash = body.indexOf('#');
    if (hash >= 0) {
      body = body.substring(0, hash);
    }
    final question = body.indexOf('?');
    if (question >= 0) {
      body = body.substring(0, question);
    }
    final decoded = decodeBase64Flex(body.trim());
    final doc = jsonDecode(decoded);
    if (doc is! Map<String, dynamic>) {
      throw const FormatException('vmess: payload not an object');
    }
    final port = doc['port'];
    return <NormalizedEndpoint>[
      VmessEndpoint(
        tag: doc['ps'] as String? ?? '${doc['add']}:$port',
        address: doc['add'] as String,
        port: intField(port, 'vmess port'),
        uuid: doc['id'] as String,
        security: doc['scy'] as String? ?? doc['security'] as String? ?? 'auto',
        alterId: doc['aid'] == null ? 0 : intField(doc['aid'], 'vmess aid'),
        network: doc['net'] as String?,
        tls: doc['tls'] == 'tls' ? 'tls' : null,
        sni: doc['sni'] as String?,
        wsPath: doc['path'] as String?,
      ),
    ];
  }
}

/// `ss://base64(method:pass)@host:port#tag` or `ss://base64(all)#tag`.
class ShadowsocksUriParser {
  List<NormalizedEndpoint> parse(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith('ss://')) {
      throw FormatException('not an ss link: $trimmed');
    }
    // No Uri.parse for the whole-link form: base64 in host position would be
    // lowercased.
    var body = trimmed.substring('ss://'.length);
    String tag;
    final hash = body.indexOf('#');
    if (hash >= 0) {
      tag = Uri.decodeComponent(body.substring(hash + 1));
      body = body.substring(0, hash);
    } else {
      tag = 'ss';
    }
    final slash = body.indexOf('/');
    if (slash >= 0) {
      body = body.substring(0, slash);
    }
    final at = body.lastIndexOf('@');
    if (at >= 0) {
      final userInfo = _decodeUser(body.substring(0, at));
      final hostPort = body.substring(at + 1);
      final split = hostPort.lastIndexOf(':');
      if (split < 0) {
        throw const FormatException('ss: missing port');
      }
      return <NormalizedEndpoint>[
        _fromUserInfo(
          userInfo,
          hostPort.substring(0, split),
          intOf(hostPort.substring(split + 1), 'ss port'),
          tag,
        ),
      ];
    }
    // whole-link base64: base64(method:password@host:port)
    final decoded = decodeBase64Flex(body.trim());
    final at2 = decoded.lastIndexOf('@');
    if (at2 < 0) {
      throw const FormatException('ss: decoded payload missing @');
    }
    final userInfo = decoded.substring(0, at2);
    final hostPort = decoded.substring(at2 + 1);
    final split = hostPort.lastIndexOf(':');
    if (split < 0) {
      throw const FormatException('ss: decoded payload missing port');
    }
    return <NormalizedEndpoint>[
      _fromUserInfo(
        userInfo,
        hostPort.substring(0, split),
        intOf(hostPort.substring(split + 1), 'ss port'),
        tag,
      ),
    ];
  }

  String _decodeUser(String source) {
    return decodeBase64Flex(source.trim());
  }

  ShadowsocksEndpoint _fromUserInfo(
    String userInfo,
    String host,
    int port,
    String tag,
  ) {
    final split = userInfo.indexOf(':');
    if (split < 0) {
      throw const FormatException('ss: userinfo not method:password');
    }
    return ShadowsocksEndpoint(
      tag: tag,
      address: host,
      port: port,
      method: userInfo.substring(0, split),
      password: userInfo.substring(split + 1),
    );
  }
}

/// `trojan://password@host:port?sni=#tag`.
class TrojanUriParser {
  List<NormalizedEndpoint> parse(String raw) {
    final uri = parseShareUri(raw);
    if (uri.scheme != 'trojan') {
      throw FormatException('not a trojan link: ${uri.scheme}');
    }
    final query = queryOf(uri);
    final tag = uri.fragment.isNotEmpty
        ? Uri.decodeComponent(uri.fragment)
        : '${uri.host}:${uri.port}';
    return <NormalizedEndpoint>[
      TrojanEndpoint(
        tag: tag,
        address: uri.host,
        port: uri.port == 0 ? 443 : uri.port,
        password: uri.userInfo,
        sni: query['sni'] ?? query['peer'],
        network: query['type'],
        allowInsecure: boolOf(query['allowInsecure']),
      ),
    ];
  }
}

/// `hysteria2://auth@host:port?mport=&obfs=salamander&obfs-password=#tag`.
class Hysteria2UriParser {
  List<NormalizedEndpoint> parse(String raw) {
    final uri = parseShareUri(raw);
    if (uri.scheme != 'hysteria2' && uri.scheme != 'hy2') {
      throw FormatException('not a hysteria2 link: ${uri.scheme}');
    }
    final query = queryOf(uri);
    final tag = uri.fragment.isNotEmpty
        ? Uri.decodeComponent(uri.fragment)
        : '${uri.host}:${uri.port}';
    final mport = query['mport'];
    return <NormalizedEndpoint>[
      Hysteria2Endpoint(
        tag: tag,
        address: uri.host,
        port: uri.port == 0 ? 443 : uri.port,
        auth: uri.userInfo,
        sni: query['sni'],
        obfsPassword: query['obfs-password'],
        ports: mport,
        hopIntervalSeconds: query['hopIntervalSeconds'] == null
            ? null
            : intOf(query['hopIntervalSeconds']!, 'hop interval'),
        insecure: boolOf(query['insecure']),
      ),
    ];
  }
}

/// `tuic://uuid:password@host:port?congestion_control=#tag`.
class TuicUriParser {
  List<NormalizedEndpoint> parse(String raw) {
    final uri = parseShareUri(raw);
    if (uri.scheme != 'tuic') {
      throw FormatException('not a tuic link: ${uri.scheme}');
    }
    final query = queryOf(uri);
    final tag = uri.fragment.isNotEmpty
        ? Uri.decodeComponent(uri.fragment)
        : '${uri.host}:${uri.port}';
    final split = uri.userInfo.indexOf(':');
    return <NormalizedEndpoint>[
      TuicEndpoint(
        tag: tag,
        address: uri.host,
        port: uri.port == 0 ? 443 : uri.port,
        uuid: split < 0 ? uri.userInfo : uri.userInfo.substring(0, split),
        password: split < 0 ? '' : uri.userInfo.substring(split + 1),
        congestionControl: query['congestion_control'],
        alpn: (query['alpn'] ?? 'h3').split(','),
        sni: query['sni'],
        udpRelayMode: query['udp_relay_mode'],
      ),
    ];
  }
}

/// WireGuard/AWG INI: `[Interface]` + repeated `[Peer]` sections, Amnezia
/// keys. Multi-peer configs produce one peer each; allowed_ips accumulate
/// per-peer, not globally.
class WgIniParser {
  List<NormalizedEndpoint> parse(String source, {String? tag}) {
    String? privateKey;
    final addresses = <String>[];
    int? mtu;
    final awg = <String, Object?>{};

    final peers = <WireGuardPeer>[];
    String? peerPublicKey;
    String? peerPresharedKey;
    String? peerEndpoint;
    int? peerKeepalive;
    final peerAllowedIps = <String>[];
    var inPeerSection = false;

    void flushPeer() {
      if (peerPublicKey != null || peerEndpoint != null) {
        peers.add(
          WireGuardPeer(
            publicKey: peerPublicKey ?? '',
            endpoint: peerEndpoint ?? '',
            allowedIps: List<String>.from(peerAllowedIps),
            presharedKey: peerPresharedKey,
            persistentKeepalive: peerKeepalive,
          ),
        );
      }
      peerPublicKey = null;
      peerPresharedKey = null;
      peerEndpoint = null;
      peerKeepalive = null;
      peerAllowedIps.clear();
    }

    for (final rawLine in source.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }
      final section = RegExp(r'^\[(.+)\]$').firstMatch(line);
      if (section != null) {
        final name = section.group(1)!.toLowerCase();
        if (name == 'peer') {
          flushPeer();
          inPeerSection = true;
        } else if (name == 'interface') {
          flushPeer();
          inPeerSection = false;
        }
        continue;
      }
      final eq = line.indexOf('=');
      if (eq < 0) {
        continue;
      }
      final key = line.substring(0, eq).trim().toLowerCase();
      final value = line.substring(eq + 1).trim();
      if (inPeerSection) {
        switch (key) {
          case 'publickey':
            peerPublicKey = value;
          case 'presharedkey':
            peerPresharedKey = value;
          case 'endpoint':
            peerEndpoint = value;
          case 'persistentkeepalive':
            peerKeepalive = intOf(value, 'keepalive');
          case 'allowedips':
            peerAllowedIps.addAll(value.split(',').map((a) => a.trim()));
        }
        continue;
      }
      switch (key) {
        case 'privatekey':
          privateKey = value;
        case 'address':
          addresses.addAll(value.split(',').map((a) => a.trim()));
        case 'mtu':
          mtu = intOf(value, 'mtu');
        case 'jc':
          awg['jc'] = intOf(value, 'Jc');
        case 'jmin':
          awg['jmin'] = intOf(value, 'Jmin');
        case 'jmax':
          awg['jmax'] = intOf(value, 'Jmax');
        case 's1':
          awg['s1'] = intOf(value, 'S1');
        case 's2':
          awg['s2'] = intOf(value, 'S2');
        case 's3':
          awg['s3'] = intOf(value, 'S3');
        case 's4':
          awg['s4'] = intOf(value, 'S4');
        case 'h1':
          awg['h1'] = value;
        case 'h2':
          awg['h2'] = value;
        case 'h3':
          awg['h3'] = value;
        case 'h4':
          awg['h4'] = value;
        case 'i1':
          awg['i1'] = value;
        case 'i2':
          awg['i2'] = value;
        case 'i3':
          awg['i3'] = value;
        case 'i4':
          awg['i4'] = value;
        case 'i5':
          awg['i5'] = value;
        case 'id':
          awg['id'] = value;
        case 'ip':
          awg['ip'] = value;
        case 'ib':
          awg['ib'] = value;
      }
    }
    flushPeer();

    if (privateKey == null) {
      throw const FormatException('wg ini: missing PrivateKey');
    }
    return <NormalizedEndpoint>[
      WireGuardEndpoint(
        tag: tag ?? 'wg',
        privateKey: privateKey,
        addresses: addresses,
        mtu: mtu,
        peers: peers,
        awg: awg.isEmpty
            ? null
            : AwgValues(
                jc: awg['jc'] as int?,
                jmin: awg['jmin'] as int?,
                jmax: awg['jmax'] as int?,
                s1: awg['s1'] as int?,
                s2: awg['s2'] as int?,
                s3: awg['s3'] as int?,
                s4: awg['s4'] as int?,
                h1: awg['h1'] as String?,
                h2: awg['h2'] as String?,
                h3: awg['h3'] as String?,
                h4: awg['h4'] as String?,
                i1: awg['i1'] as String?,
                i2: awg['i2'] as String?,
                i3: awg['i3'] as String?,
                i4: awg['i4'] as String?,
                i5: awg['i5'] as String?,
                id: awg['id'] as String?,
                ip: awg['ip'] as String?,
                ib: awg['ib'] as String?,
              ),
      ),
    ];
  }
}
