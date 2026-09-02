import 'dart:convert';

import 'normalized_endpoint.dart';
import 'parsers.dart';

export 'normalized_endpoint.dart';
export 'parsers.dart';

class RawSubscription {
  const RawSubscription({
    required this.bytes,
    required this.url,
    this.contentType,
  });

  final List<int> bytes;
  final Uri url;
  final String? contentType;
}

/// Deep adapter unifying all subscription formats into [NormalizedEndpoint]
/// sealed-union records.
///
/// Dispatch is content-sniffed: wg INI, clash YAML, sing-box/SIP008 JSON, then
/// share-link lines (vless/vmess/ss/trojan/hysteria2/tuic), optionally wrapped
/// in a base64 bundle. Parsed results are cached per URL for 6 hours.
class IngestionAdapter {
  IngestionAdapter({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Map<Uri, _CachedParse> _cache = <Uri, _CachedParse>{};

  List<NormalizedEndpoint> parseAndNormalize(RawSubscription subscription) {
    final cached = _cache[subscription.url];
    if (cached != null &&
        _now().difference(cached.parsedAt) < const Duration(hours: 6)) {
      return cached.endpoints;
    }
    final endpoints = _parse(subscription);
    _cache[subscription.url] = _CachedParse(endpoints, _now());
    return endpoints;
  }

  List<NormalizedEndpoint> _parse(RawSubscription subscription) {
    final source = utf8.decode(subscription.bytes, allowMalformed: true);
    if (source.trim().isEmpty) {
      throw const FormatException('subscription is empty');
    }

    if (_looksLikeWgIni(source)) {
      return WgIniParser().parse(source);
    }
    if (_looksLikeClashYaml(source)) {
      return ClashYamlParser().parse(source);
    }
    if (_looksLikeJson(source)) {
      return SingboxJsonParser().parse(source);
    }

    final lines = _shareLines(source);
    return parseShareLines(lines);
  }

  /// Parses a list of share-link lines, unwrapping one base64 level when the
  /// whole payload is a bundle.
  List<NormalizedEndpoint> parseShareLines(List<String> lines) {
    final endpoints = <NormalizedEndpoint>[];
    final failures = <FormatException>[];
    for (final line in lines) {
      try {
        endpoints.addAll(_parseOne(line));
      } on FormatException catch (e) {
        failures.add(e);
      }
    }
    if (endpoints.isEmpty && failures.isNotEmpty) {
      throw FormatException(
        'no share links parsed (${failures.length} malformed lines)',
      );
    }
    return endpoints;
  }

  List<NormalizedEndpoint> _parseOne(String line) {
    final scheme = line.contains('://') ? line.split('://').first : '';
    switch (scheme) {
      case 'vless':
        return VlessUriParser().parse(line);
      case 'vmess':
        return VmessUriParser().parse(line);
      case 'ss':
        return ShadowsocksUriParser().parse(line);
      case 'trojan':
        return TrojanUriParser().parse(line);
      case 'hysteria2':
      case 'hy2':
        return Hysteria2UriParser().parse(line);
      case 'tuic':
        return TuicUriParser().parse(line);
      default:
        throw FormatException('unsupported scheme "$scheme"');
    }
  }

  bool _looksLikeWgIni(String source) =>
      RegExp(r'^\s*\[Interface\]', multiLine: true).hasMatch(source);

  bool _looksLikeClashYaml(String source) =>
      RegExp(r'^\s*(proxies|listeners)\s*:', multiLine: true).hasMatch(source) &&
      !source.trimLeft().startsWith('{');

  bool _looksLikeJson(String source) {
    final trimmed = source.trimLeft();
    if (!trimmed.startsWith('{')) {
      return false;
    }
    return trimmed.contains('"outbounds"') ||
        trimmed.contains('"endpoints"') ||
        trimmed.contains('"servers"');
  }

  List<String> _shareLines(String source) {
    final lines = source
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final hasScheme = lines.any((l) => RegExp(r'^\w+://').hasMatch(l));
    if (hasScheme) {
      return lines;
    }
    // One base64 level unwraps a bundled subscription.
    try {
      final decoded = utf8.decode(
        base64Url.decode(base64Url.normalize(source.replaceAll(RegExp(r'\s'), ''))),
      );
      return decoded
          .split(RegExp(r'\r?\n'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
    } on Object {
      return lines;
    }
  }
}

class _CachedParse {
  const _CachedParse(this.endpoints, this.parsedAt);

  final List<NormalizedEndpoint> endpoints;
  final DateTime parsedAt;
}
