import '../../../../utils/amnezia_values.dart';

export '../../../../utils/amnezia_values.dart' show AwgValues;

/// Sealed union of normalized endpoints produced by [IngestionAdapter].
///
/// One variant per protocol family. Format quirks (Clash `mixed-port` vs
/// `listeners`, SIP008 `server_key`, VLESS `reality pbk/sid`, TUIC
/// `congestion_control`, WG INI `preshared_key`, `amnezia_values` presets)
/// are resolved inside the parsers; callers switch on the variant.
sealed class NormalizedEndpoint {
  const NormalizedEndpoint({required this.tag});

  final String tag;
}

class WireGuardEndpoint extends NormalizedEndpoint {
  const WireGuardEndpoint({
    required super.tag,
    required this.privateKey,
    required this.addresses,
    required this.peers,
    this.mtu,
    this.awg,
  });

  final String privateKey;
  final List<String> addresses;
  final List<WireGuardPeer> peers;
  final int? mtu;

  /// Present when the source carried AmneziaWG obfuscation values.
  final AwgValues? awg;
}

class WireGuardPeer {
  const WireGuardPeer({
    required this.publicKey,
    required this.endpoint,
    required this.allowedIps,
    this.presharedKey,
    this.persistentKeepalive,
  });

  final String publicKey;
  final String endpoint;
  final List<String> allowedIps;
  final String? presharedKey;
  final int? persistentKeepalive;
}

/// V2Ray transport layer for vless/vmess/trojan, as the fork's
/// `option/v2ray_transport.go` accepts it: ws, grpc, httpupgrade, xhttp,
/// http (quic exists in the enum but no real-world link carries it — parsed
/// and passed through type-only). Field shapes are probe-verified against
/// `windows/sing-box.exe check` (see endpoint_outbound.dart header).
class TransportOptions {
  const TransportOptions({
    required this.type,
    this.path,
    this.host,
    this.headers,
    this.serviceName,
    this.mode,
    this.idleTimeoutSeconds,
    this.pingTimeoutSeconds,
    this.method,
  });

  final String type;

  /// ws / xhttp / httpupgrade / http path.
  final String? path;

  /// Single-string host (ws header, httpupgrade, xhttp); http emits it as
  /// the 1-element Listable array the fork wants.
  final String? host;

  /// Extra headers (ws Host header handled via [host]; xhttp FATALs on a
  /// host key — the emitter strips it).
  final Map<String, String>? headers;

  /// grpc only.
  final String? serviceName;

  /// xhttp only: auto | packet-up | stream-up | stream-one.
  final String? mode;

  /// grpc/http durations, emitted as `<n>s`.
  final int? idleTimeoutSeconds;
  final int? pingTimeoutSeconds;

  /// http only (GET/PUT/...).
  final String? method;
}

/// AmneziaWG obfuscation values, either parsed from the source or resolved

class VlessEndpoint extends NormalizedEndpoint {
  const VlessEndpoint({
    required super.tag,
    required this.address,
    required this.port,
    required this.uuid,
    this.flow,
    this.network,
    this.security,
    this.sni,
    this.fingerprint,
    this.realityPublicKey,
    this.realityShortId,
    this.wsPath,
    this.wsHost,
    this.transport,
    this.echEnabled = false,
    this.echConfig,
  });

  final String address;
  final int port;
  final String uuid;
  final String? flow;
  final String? network;
  final String? security;
  final String? sni;
  final String? fingerprint;
  final String? realityPublicKey;
  final String? realityShortId;
  final String? wsPath;
  final String? wsHost;

  /// Typed transport; wins over the legacy [wsPath]/[wsHost] pair when set.
  final TransportOptions? transport;

  /// ECH (tls.ech): enabled without config fetches ECH configs from DNS
  /// HTTPS records at runtime; [echConfig] carries a PEM `ECH CONFIGS`
  /// block when the source supplied one.
  final bool echEnabled;
  final String? echConfig;
}

class VmessEndpoint extends NormalizedEndpoint {
  const VmessEndpoint({
    required super.tag,
    required this.address,
    required this.port,
    required this.uuid,
    required this.security,
    this.alterId = 0,
    this.network,
    this.tls,
    this.sni,
    this.wsPath,
    this.transport,
  });

  final String address;
  final int port;
  final String uuid;
  final String security;
  final int alterId;
  final String? network;
  final String? tls;
  final String? sni;
  final String? wsPath;
  final TransportOptions? transport;
}

class ShadowsocksEndpoint extends NormalizedEndpoint {
  const ShadowsocksEndpoint({
    required super.tag,
    required this.address,
    required this.port,
    required this.method,
    required this.password,
    this.plugin,
    this.pluginOpts,
  });

  final String address;
  final int port;
  final String method;
  final String password;
  final String? plugin;
  final Map<String, String>? pluginOpts;
}

class TrojanEndpoint extends NormalizedEndpoint {
  const TrojanEndpoint({
    required super.tag,
    required this.address,
    required this.port,
    required this.password,
    this.sni,
    this.network,
    this.allowInsecure = false,
    this.transport,
  });

  final String address;
  final int port;
  final String password;
  final String? sni;
  final String? network;
  final bool allowInsecure;

  /// Trojan ws path/host were parsed-and-dropped before; the typed
  /// transport captures them (emit previously shipped `{'type': 'ws'}` bare).
  final TransportOptions? transport;
}

/// SSH outbound (fork `option/ssh.go`, outbound-only — endpoints[] rejects
/// ssh, probed). Auth is password OR key; keys in OpenSSH-PEM / PKCS8 /
/// PKCS1-RSA PEM parse via x/crypto/ssh (all probed EXIT=0), but
/// `ssh-keygen -m PKCS8 -e` export output does NOT (`ssh: no key found`) —
/// store the key verbatim and validate at emit.
class SshEndpoint extends NormalizedEndpoint {
  const SshEndpoint({
    required super.tag,
    required this.address,
    required this.port,
    this.user = 'root',
    this.password,
    this.privateKey,
    this.privateKeyPassphrase,
    this.hostKey,
  });

  final String address;
  final int port;

  /// Defaults to 'root' engine-side when empty.
  final String user;

  /// Password auth (probed to pass check alone).
  final String? password;

  /// PEM private key, verbatim (multi-line). Embedded key wins over
  /// private_key_path engine-side; we never emit the path form.
  final String? privateKey;

  final String? privateKeyPassphrase;

  /// authorized_keys-format lines parsed engine-side at check.
  final List<String>? hostKey;
}

class Hysteria2Endpoint extends NormalizedEndpoint {
  const Hysteria2Endpoint({
    required super.tag,
    required this.address,
    required this.port,
    required this.auth,
    this.sni,
    this.obfsPassword,
    this.upMbps,
    this.downMbps,
    this.ports,
    this.hopIntervalSeconds,
    this.insecure = false,
  });

  final String address;
  final int port;
  final String auth;
  final String? sni;
  final String? obfsPassword;
  final int? upMbps;
  final int? downMbps;

  /// Port hopping range, e.g. `20000-30000`.
  final String? ports;
  final int? hopIntervalSeconds;
  final bool insecure;
}

class TuicEndpoint extends NormalizedEndpoint {
  const TuicEndpoint({
    required super.tag,
    required this.address,
    required this.port,
    required this.uuid,
    required this.password,
    this.congestionControl,
    this.alpn = const <String>['h3'],
    this.sni,
    this.udpRelayMode,
  });

  final String address;
  final int port;
  final String uuid;
  final String password;
  final String? congestionControl;
  final List<String> alpn;
  final String? sni;
  final String? udpRelayMode;
}

/// Store-facing (de)serialization for the sealed union. `kind` is the
/// discriminator; every field is optional-tolerant so a schema evolution
/// never bricks the stored list.
Map<String, dynamic> _transportToJson(TransportOptions? t) {
  if (t == null) {
    return <String, dynamic>{};
  }
  return <String, dynamic>{
    'type': t.type,
    'path': t.path,
    'host': t.host,
    'headers': t.headers,
    'serviceName': t.serviceName,
    'mode': t.mode,
    'idleTimeoutSeconds': t.idleTimeoutSeconds,
    'pingTimeoutSeconds': t.pingTimeoutSeconds,
    'method': t.method,
  };
}

TransportOptions? _transportFromJson(Map<String, dynamic>? raw) {
  if (raw == null || raw.isEmpty || raw['type'] == null) {
    return null;
  }
  return TransportOptions(
    type: raw['type'] as String,
    path: raw['path'] as String?,
    host: raw['host'] as String?,
    headers: raw['headers']?.cast<String, String>(),
    serviceName: raw['serviceName'] as String?,
    mode: raw['mode'] as String?,
    idleTimeoutSeconds: raw['idleTimeoutSeconds'] as int?,
    pingTimeoutSeconds: raw['pingTimeoutSeconds'] as int?,
    method: raw['method'] as String?,
  );
}

Map<String, dynamic> normalizedToJson(NormalizedEndpoint e) {
  final json = <String, dynamic>{
    'kind': e.runtimeType.toString(),
    'tag': e.tag,
  };
  switch (e) {
    case WireGuardEndpoint():
      json
        ..['privateKey'] = e.privateKey
        ..['addresses'] = e.addresses
        ..['peers'] = <Map<String, dynamic>>[
          for (final p in e.peers)
            <String, dynamic>{
              'publicKey': p.publicKey,
              'endpoint': p.endpoint,
              'allowedIps': p.allowedIps,
              if (p.presharedKey != null) 'presharedKey': p.presharedKey,
              if (p.persistentKeepalive != null)
                'persistentKeepalive': p.persistentKeepalive,
            },
        ]
        ..['mtu'] = e.mtu
        ..['awg'] = e.awg?.toJson();
    case VlessEndpoint():
      json
        ..['address'] = e.address
        ..['port'] = e.port
        ..['uuid'] = e.uuid
        ..['flow'] = e.flow
        ..['network'] = e.network
        ..['security'] = e.security
        ..['sni'] = e.sni
        ..['fingerprint'] = e.fingerprint
        ..['realityPublicKey'] = e.realityPublicKey
        ..['realityShortId'] = e.realityShortId
        ..['wsPath'] = e.wsPath
        ..['wsHost'] = e.wsHost
        ..['transport'] = _transportToJson(e.transport)
        ..['echEnabled'] = e.echEnabled
        ..['echConfig'] = e.echConfig;
    case VmessEndpoint():
      json
        ..['address'] = e.address
        ..['port'] = e.port
        ..['uuid'] = e.uuid
        ..['security'] = e.security
        ..['alterId'] = e.alterId
        ..['network'] = e.network
        ..['tls'] = e.tls
        ..['sni'] = e.sni
        ..['wsPath'] = e.wsPath
        ..['transport'] = _transportToJson(e.transport);
    case TrojanEndpoint():
      json
        ..['address'] = e.address
        ..['port'] = e.port
        ..['password'] = e.password
        ..['sni'] = e.sni
        ..['network'] = e.network
        ..['allowInsecure'] = e.allowInsecure
        ..['transport'] = _transportToJson(e.transport);
    case SshEndpoint():
      json
        ..['address'] = e.address
        ..['port'] = e.port
        ..['user'] = e.user
        ..['password'] = e.password
        ..['privateKey'] = e.privateKey
        ..['privateKeyPassphrase'] = e.privateKeyPassphrase
        ..['hostKey'] = e.hostKey;
    case ShadowsocksEndpoint():
      json
        ..['address'] = e.address
        ..['port'] = e.port
        ..['method'] = e.method
        ..['password'] = e.password
        ..['plugin'] = e.plugin
        ..['pluginOpts'] = e.pluginOpts;
    case Hysteria2Endpoint():
      json
        ..['address'] = e.address
        ..['port'] = e.port
        ..['auth'] = e.auth
        ..['sni'] = e.sni
        ..['obfsPassword'] = e.obfsPassword
        ..['upMbps'] = e.upMbps
        ..['downMbps'] = e.downMbps
        ..['ports'] = e.ports
        ..['hopIntervalSeconds'] = e.hopIntervalSeconds
        ..['insecure'] = e.insecure;
    case TuicEndpoint():
      json
        ..['address'] = e.address
        ..['port'] = e.port
        ..['uuid'] = e.uuid
        ..['password'] = e.password
        ..['congestionControl'] = e.congestionControl
        ..['alpn'] = e.alpn
        ..['sni'] = e.sni
        ..['udpRelayMode'] = e.udpRelayMode;
  }
  return json;
}

NormalizedEndpoint normalizedFromJson(Map<String, dynamic> json) {
  switch (json['kind'] as String?) {
    case 'WireGuardEndpoint':
      return WireGuardEndpoint(
        tag: json['tag'] as String? ?? 'wg',
        privateKey: json['privateKey'] as String? ?? '',
        addresses: <String>[...?json['addresses'] as List<dynamic>?],
        mtu: json['mtu'] as int?,
        awg: json['awg'] == null
            ? null
            : AwgValues(
                jc: (json['awg'] as Map<String, dynamic>)['jc'] as int?,
                jmin: (json['awg'] as Map<String, dynamic>)['jmin'] as int?,
                jmax: (json['awg'] as Map<String, dynamic>)['jmax'] as int?,
                s1: (json['awg'] as Map<String, dynamic>)['s1'] as int?,
                s2: (json['awg'] as Map<String, dynamic>)['s2'] as int?,
                s3: (json['awg'] as Map<String, dynamic>)['s3'] as int?,
                s4: (json['awg'] as Map<String, dynamic>)['s4'] as int?,
                h1: (json['awg'] as Map<String, dynamic>)['h1'] as String?,
                h2: (json['awg'] as Map<String, dynamic>)['h2'] as String?,
                h3: (json['awg'] as Map<String, dynamic>)['h3'] as String?,
                h4: (json['awg'] as Map<String, dynamic>)['h4'] as String?,
                i1: (json['awg'] as Map<String, dynamic>)['i1'] as String?,
                i2: (json['awg'] as Map<String, dynamic>)['i2'] as String?,
                i3: (json['awg'] as Map<String, dynamic>)['i3'] as String?,
                i4: (json['awg'] as Map<String, dynamic>)['i4'] as String?,
                i5: (json['awg'] as Map<String, dynamic>)['i5'] as String?,
                id: (json['awg'] as Map<String, dynamic>)['id'] as String?,
                ip: (json['awg'] as Map<String, dynamic>)['ip'] as String?,
                ib: (json['awg'] as Map<String, dynamic>)['ib'] as String?,
              ),
        peers: <WireGuardPeer>[
          for (final p in json['peers'] as List<dynamic>? ?? const <dynamic>[])
            WireGuardPeer(
              publicKey:
                  (p as Map<String, dynamic>)['publicKey'] as String? ?? '',
              endpoint: p['endpoint'] as String? ?? '',
              allowedIps: <String>[...?p['allowedIps'] as List<dynamic>?],
              presharedKey: p['presharedKey'] as String?,
              persistentKeepalive: p['persistentKeepalive'] as int?,
            ),
        ],
      );
    case 'VlessEndpoint':
      return VlessEndpoint(
        tag: json['tag'] as String? ?? 'vless',
        address: json['address'] as String? ?? '',
        port: json['port'] as int? ?? 443,
        uuid: json['uuid'] as String? ?? '',
        flow: json['flow'] as String?,
        network: json['network'] as String?,
        security: json['security'] as String?,
        sni: json['sni'] as String?,
        fingerprint: json['fingerprint'] as String?,
        realityPublicKey: json['realityPublicKey'] as String?,
        realityShortId: json['realityShortId'] as String?,
        wsPath: json['wsPath'] as String?,
        wsHost: json['wsHost'] as String?,
        transport: _transportFromJson(
          json['transport'] as Map<String, dynamic>?,
        ),
        echEnabled: json['echEnabled'] as bool? ?? false,
        echConfig: json['echConfig'] as String?,
      );
    case 'VmessEndpoint':
      return VmessEndpoint(
        tag: json['tag'] as String? ?? 'vmess',
        address: json['address'] as String? ?? '',
        port: json['port'] as int? ?? 443,
        uuid: json['uuid'] as String? ?? '',
        security: json['security'] as String? ?? 'auto',
        alterId: json['alterId'] as int? ?? 0,
        network: json['network'] as String?,
        tls: json['tls'] as String?,
        sni: json['sni'] as String?,
        wsPath: json['wsPath'] as String?,
        transport: _transportFromJson(
          json['transport'] as Map<String, dynamic>?,
        ),
      );
    case 'ShadowsocksEndpoint':
      return ShadowsocksEndpoint(
        tag: json['tag'] as String? ?? 'ss',
        address: json['address'] as String? ?? '',
        port: json['port'] as int? ?? 8388,
        method: json['method'] as String? ?? 'aes-256-gcm',
        password: json['password'] as String? ?? '',
        plugin: json['plugin'] as String?,
        pluginOpts: (json['pluginOpts'] as Map<String, dynamic>?)
            ?.cast<String, String>(),
      );
    case 'TrojanEndpoint':
      return TrojanEndpoint(
        tag: json['tag'] as String? ?? 'trojan',
        address: json['address'] as String? ?? '',
        port: json['port'] as int? ?? 443,
        password: json['password'] as String? ?? '',
        sni: json['sni'] as String?,
        network: json['network'] as String?,
        allowInsecure: json['allowInsecure'] as bool? ?? false,
        transport: _transportFromJson(
          json['transport'] as Map<String, dynamic>?,
        ),
      );
    case 'SshEndpoint':
      return SshEndpoint(
        tag: json['tag'] as String? ?? 'ssh',
        address: json['address'] as String? ?? '',
        port: json['port'] as int? ?? 22,
        user: json['user'] as String? ?? 'root',
        password: json['password'] as String?,
        privateKey: json['privateKey'] as String?,
        privateKeyPassphrase: json['privateKeyPassphrase'] as String?,
        hostKey: json['hostKey'] == null
            ? null
            : List<String>.from(json['hostKey'] as List<dynamic>),
      );
    case 'Hysteria2Endpoint':
      return Hysteria2Endpoint(
        tag: json['tag'] as String? ?? 'hy2',
        address: json['address'] as String? ?? '',
        port: json['port'] as int? ?? 443,
        auth: json['auth'] as String? ?? '',
        sni: json['sni'] as String?,
        obfsPassword: json['obfsPassword'] as String?,
        upMbps: json['upMbps'] as int?,
        downMbps: json['downMbps'] as int?,
        ports: json['ports'] as String?,
        hopIntervalSeconds: json['hopIntervalSeconds'] as int?,
        insecure: json['insecure'] as bool? ?? false,
      );
    case 'TuicEndpoint':
      return TuicEndpoint(
        tag: json['tag'] as String? ?? 'tuic',
        address: json['address'] as String? ?? '',
        port: json['port'] as int? ?? 443,
        uuid: json['uuid'] as String? ?? '',
        password: json['password'] as String? ?? '',
        congestionControl: json['congestionControl'] as String?,
        alpn: <String>[...?json['alpn'] as List<dynamic>?],
        sni: json['sni'] as String?,
        udpRelayMode: json['udpRelayMode'] as String?,
      );
    default:
      throw FormatException('unknown endpoint kind: ${json['kind']}');
  }
}
