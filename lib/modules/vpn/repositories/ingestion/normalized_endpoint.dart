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
  });

  final String address;
  final int port;
  final String password;
  final String? sni;
  final String? network;
  final bool allowInsecure;
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
