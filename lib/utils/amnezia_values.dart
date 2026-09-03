/// AmneziaWG obfuscation values shared by ingestion parsers and the AWG
/// domain module, plus presets and a validated-shape random draw.
///
/// Must-match group: `H1-H4` and `I1-I5` are per-peer constants the server
/// must agree on. May-differ group: `Jc/Jmin/Jmax/S1-S4` only change the wire
/// shape, any valid values interoperate.
library;

import 'dart:math';

class AwgValues {
  const AwgValues({
    this.jc,
    this.jmin,
    this.jmax,
    this.s1,
    this.s2,
    this.s3,
    this.s4,
    this.h1,
    this.h2,
    this.h3,
    this.h4,
    this.i1,
    this.i2,
    this.i3,
    this.i4,
    this.i5,
    this.id,
    this.ip,
    this.ib,
  });

  final int? jc;
  final int? jmin;
  final int? jmax;
  final int? s1;
  final int? s2;
  final int? s3;
  final int? s4;
  final String? h1;
  final String? h2;
  final String? h3;
  final String? h4;
  final String? i1;
  final String? i2;
  final String? i3;
  final String? i4;
  final String? i5;
  final String? id;
  final String? ip;
  final String? ib;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (jc != null) 'jc': jc,
    if (jmin != null) 'jmin': jmin,
    if (jmax != null) 'jmax': jmax,
    if (s1 != null) 's1': s1,
    if (s2 != null) 's2': s2,
    if (s3 != null) 's3': s3,
    if (s4 != null) 's4': s4,
    if (h1 != null) 'h1': h1,
    if (h2 != null) 'h2': h2,
    if (h3 != null) 'h3': h3,
    if (h4 != null) 'h4': h4,
    if (i1 != null) 'i1': i1,
    if (i2 != null) 'i2': i2,
    if (i3 != null) 'i3': i3,
    if (i4 != null) 'i4': i4,
    if (i5 != null) 'i5': i5,
    if (id != null) 'id': id,
    if (ip != null) 'ip': ip,
    if (ib != null) 'ib': ib,
  };

  /// The subset this engine actually accepts. `id`/`ip`/`ib` are WireSock
  /// masquerade keys; the fork's option struct has no such fields and its
  /// config parser FATALs on unknown fields (probed: `endpoints[0].id: json:
  /// unknown field "id"`). They stay on the model for editor round-trips but
  /// must never reach the engine JSON.
  Map<String, dynamic> toEngineJson() => <String, dynamic>{
    if (jc != null) 'jc': jc,
    if (jmin != null) 'jmin': jmin,
    if (jmax != null) 'jmax': jmax,
    if (s1 != null) 's1': s1,
    if (s2 != null) 's2': s2,
    if (s3 != null) 's3': s3,
    if (s4 != null) 's4': s4,
    if (h1 != null) 'h1': h1,
    if (h2 != null) 'h2': h2,
    if (h3 != null) 'h3': h3,
    if (h4 != null) 'h4': h4,
    if (i1 != null) 'i1': i1,
    if (i2 != null) 'i2': i2,
    if (i3 != null) 'i3': i3,
    if (i4 != null) 'i4': i4,
    if (i5 != null) 'i5': i5,
  };
}

enum AwgPreset { quicMimic, balanced, stealth }

/// Preset draws. Validation lives with AwgConfig (`H1∩H2=∅`, `S1+56≠S2`,
/// `Jmax<MTU`) before the values reach Go.
extension AwgPresetValues on AwgPreset {
  AwgValues get values {
    switch (this) {
      case AwgPreset.quicMimic:
        // Junk that looks like QUIC Initial traffic.
        return const AwgValues(
          jc: 8,
          jmin: 40,
          jmax: 70,
          s1: 15,
          s2: 74,
          h1: '1217194092',
          h2: '1002',
          h3: '8929',
          h4: '1',
        );
      case AwgPreset.balanced:
        return const AwgValues(
          jc: 5,
          jmin: 30,
          jmax: 1000,
          s1: 56,
          s2: 152,
          h1: '1234567',
          h2: '2345678',
          h3: '3456789',
          h4: '4567890',
        );
      case AwgPreset.stealth:
        // Heavy junk + padding; widest span between S values.
        return const AwgValues(
          jc: 12,
          jmin: 50,
          jmax: 1000,
          s1: 90,
          s2: 224,
          h1: '1927465102',
          h2: '827396125',
          h3: '728491635',
          h4: '918273645',
        );
    }
  }
}

final Random _random = Random.secure();

int _randomHeader(List<int> exclude) {
  var value = 0;
  do {
    value = _random.nextInt(0xFFFFFFFE) + 1;
  } while (exclude.contains(value));
  return value;
}

/// Random validated-shaped draw. Headers never collide, `S1 + 56 != S2`
/// (init1+msg1 padding rule), `Jmax` stays under a 1280 minimal MTU.
AwgValues generateRandom() {
  final h1 = _randomHeader(<int>[]);
  final h2 = _randomHeader(<int>[h1]);
  final h3 = _randomHeader(<int>[h1, h2]);
  final h4 = _randomHeader(<int>[h1, h2, h3]);
  final s1 = 15 + _random.nextInt(100);
  var s2 = s1 + 57;
  if (s2 == s1 + 56) {
    s2 += 1;
  }
  return AwgValues(
    jc: 3 + _random.nextInt(10),
    jmin: 20,
    jmax: 500 + _random.nextInt(500),
    s1: s1,
    s2: s2,
    h1: h1.toString(),
    h2: h2.toString(),
    h3: h3.toString(),
    h4: h4.toString(),
  );
}
