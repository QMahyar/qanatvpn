import 'dart:convert';

import '../../../utils/amnezia_values.dart' show AwgValues, AwgPreset, AwgPresetValues;
import '../../../utils/amnezia_values.dart' as awg_lib;

/// Public for tests and the advanced editor: build any [AwgValues] shape and
/// let [AwgConfig.validate] report every violation at once.
AwgConfig awgConfigForTest({
  required AwgValues values,
  required String privateKey,
  required String peerPublicKey,
  required String peerEndpoint,
  required List<String> addresses,
  required int mtu,
  String? peerPresharedKey,
}) {
  return AwgConfig._(
    values: values,
    privateKey: privateKey,
    peerPublicKey: peerPublicKey,
    peerEndpoint: peerEndpoint,
    addresses: addresses,
    mtu: mtu,
    peerPresharedKey: peerPresharedKey,
  );
}

/// Validation + JSON shape for one AmneziaWG endpoint.
///
/// The constraints hidden here:
/// - `H1∩H2=∅` — the four magic header values must be pairwise distinct.
/// - `S1 + 56 ≠ S2` — init1+msg1 padding rule (56 = WireGuard init msg size).
/// - `Jmax < MTU` — junk packets larger than the MTU are dropped, and the
///   largest allowed MTU matters more than the smallest.
/// - keys are 32-byte base64 (44 chars with `=` padding).
/// - must-match group (`H1-H4`, `I1-I5`) is sent per-endpoint; may-differ
///   group (`Jc/Jmin/Jmax/S1-S4`) only shapes the wire.
class AwgConfig {
  const AwgConfig._({
    required this.values,
    required this.privateKey,
    required this.peerPublicKey,
    required this.peerEndpoint,
    required this.addresses,
    required this.mtu,
    this.peerPresharedKey,
  });

  final AwgValues values;
  final String privateKey;
  final String peerPublicKey;
  final String peerEndpoint;
  final List<String> addresses;
  final int mtu;
  final String? peerPresharedKey;
  final int persistentKeepalive = 25;

  /// Everything wrong with this config, shown at once in the advanced editor.
  List<String> validate() {
    final errors = <String>[];
    _validateKey(privateKey, 'private_key', errors);
    _validateKey(peerPublicKey, 'peer public_key', errors);
    if (peerPresharedKey != null) {
      _validateKey(peerPresharedKey!, 'preshared_key', errors);
    }
    if (peerEndpoint.isEmpty || !peerEndpoint.contains(':')) {
      errors.add('peer endpoint must be host:port');
    }
    if (addresses.isEmpty) {
      errors.add('at least one tunnel address required');
    }
    final jc = values.jc;
    if (jc != null && (jc < 0 || jc > 128)) {
      errors.add('Jc out of range 0-128: $jc');
    }
    final jmin = values.jmin ?? 0;
    final jmax = values.jmax ?? 0;
    if (jmin < 0) {
      errors.add('Jmin must be >= 0');
    }
    if (jmax < jmin) {
      errors.add('Jmax ($jmax) must be >= Jmin ($jmin)');
    }
    if (mtu <= 0 || mtu > 65535) {
      errors.add('MTU out of range: $mtu');
    } else if (jmax >= mtu) {
      errors.add('Jmax ($jmax) must be < MTU ($mtu)');
    }
    final s1 = values.s1;
    final s2 = values.s2;
    if (s1 != null && (s1 < 0 || s1 > 1500)) {
      errors.add('S1 out of range 0-1500: $s1');
    }
    if (s2 != null && (s2 < 0 || s2 > 1500)) {
      errors.add('S2 out of range 0-1500: $s2');
    }
    if (s1 != null && s2 != null && s1 + 56 == s2) {
      errors.add('S1 + 56 must not equal S2 ($s1 + 56 == $s2)');
    }
    final headers = <String?>[values.h1, values.h2, values.h3, values.h4];
    final set = headers.whereType<String>().toSet();
    final provided = headers.whereType<String>().length;
    if (set.length != provided) {
      errors.add('H1-H4 must be pairwise distinct (H1∩H2=∅ rule)');
    }
    return errors;
  }

  bool get isValid => validate().isEmpty;

  /// The `endpoints[]` entry for sing-box (awg type).
  Map<String, dynamic> toEndpointJson() {
    return <String, dynamic>{
      'type': 'awg',
      'tag': 'awg',
      'private_key': privateKey,
      'address': List<String>.from(addresses),
      'mtu': mtu,
      ...values.toJson(),
      'peers': <dynamic>[
        <String, dynamic>{
          'address': peerEndpoint.split(':').first,
          'port': int.parse(peerEndpoint.split(':').last),
          'public_key': peerPublicKey,
          if (peerPresharedKey != null) 'preshared_key': peerPresharedKey,
          'allowed_ips': <String>['0.0.0.0/0', '::/0'],
          'persistent_keepalive_interval': persistentKeepalive,
        },
      ],
    };
  }
}

/// Preset entry points over [AwgValues].
enum AwgProfile {
  quicMimic,
  balanced,
  stealth;

  AwgValues get presetValues => preset.values;

  AwgPreset get preset => switch (this) {
        AwgProfile.quicMimic => AwgPreset.quicMimic,
        AwgProfile.balanced => AwgPreset.balanced,
        AwgProfile.stealth => AwgPreset.stealth,
      };

  String get label => switch (this) {
        AwgProfile.quicMimic => 'QUIC mimic',
        AwgProfile.balanced => 'Balanced',
        AwgProfile.stealth => 'Stealth',
      };

  /// Preset + endpoint material → validated-shape [AwgConfig].
  static AwgConfig fromPreset(
    AwgProfile profile, {
    required String privateKey,
    required String peerPublicKey,
    required String peerEndpoint,
    required List<String> addresses,
    int mtu = 1408,
    String? peerPresharedKey,
  }) {
    return AwgConfig._(
      values: profile.presetValues,
      privateKey: privateKey,
      peerPublicKey: peerPublicKey,
      peerEndpoint: peerEndpoint,
      addresses: addresses,
      mtu: mtu,
      peerPresharedKey: peerPresharedKey,
    );
  }

  /// Random draw with all invariants held by construction.
  static AwgConfig generateRandom({
    required String privateKey,
    required String peerPublicKey,
    required String peerEndpoint,
    required List<String> addresses,
    int mtu = 1408,
    String? peerPresharedKey,
  }) {
    return AwgConfig._(
      values: awg_lib.generateRandom(),
      privateKey: privateKey,
      peerPublicKey: peerPublicKey,
      peerEndpoint: peerEndpoint,
      addresses: addresses,
      mtu: mtu,
      peerPresharedKey: peerPresharedKey,
    );
  }
}

void _validateKey(String key, String what, List<String> errors) {
  final validLength = key.length == 44 && key.endsWith('=');
  var validBase64 = true;
  try {
    base64Url.decode(key);
  } on FormatException {
    validBase64 = false;
  }
  if (!validLength || !validBase64) {
    errors.add('$what must be 32-byte base64 (44 chars), got ${key.length}');
  }
}
