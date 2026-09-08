import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/network/http_cache.dart';
import '../../core/persistence/atomic_write.dart';

/// Deep module owning the SRS rule-set pipeline.
///
/// `dns` and `routing` builders depend on [getPath] / [ruleSetEntries] — never
/// on HTTP. `ensure(tag)` always succeeds: live cache, then bundled initial
/// asset, then download. `refreshAll()` is ETag-aware with a 6h
/// stale-while-revalidate window and GitHub rate-limit signaling; failures
/// keep the previous bytes so the VPN config never loses geo data.
class GeoAsset {
  GeoAsset({
    required this.cacheDir,
    required this.initialDir,
    required this.http,
    this.bundledLoader,
  });

  /// Resolves a bundled initial asset by name. Default tries the Flutter
  /// asset bundle first (packaged apps — APK assets are not filesystem
  /// files) then plain File IO under [initialDir] (dev runs + tests).
  /// Injectable so tests pin exact bytes without the asset bundle.
  Future<Uint8List?> Function(String fileName)? bundledLoader;

  /// Where live (downloaded) assets are stored.
  final Directory cacheDir;

  /// Bundled offline fallbacks, e.g. `rule_sets/initial_assets/`.
  final Directory initialDir;

  final HttpCache http;

  static const Map<String, GeoAssetSpec> registry = <String, GeoAssetSpec>{
    'geosite-cn': GeoAssetSpec(
      url:
          'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs',
      initialFile: 'geosite-cn.srs',
      type: 'domain',
    ),
    'geoip-cn': GeoAssetSpec(
      url:
          'https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs',
      initialFile: 'geoip-cn.srs',
      type: 'ip',
    ),
  };

  /// Absolute path of the asset for [tag], copying the bundled fallback in
  /// when the cache is empty. Never throws for known tags with a fallback.
  Future<String> ensure(String tag) async {
    final spec = registry[tag];
    if (spec == null) {
      throw ArgumentError('unknown geo asset: $tag');
    }
    final cached = File('${cacheDir.path}/$tag.srs');
    if (cached.existsSync()) {
      return cached.path;
    }
    await cacheDir.create(recursive: true);
    final bundled = await _loadBundled(spec.initialFile);
    if (bundled != null) {
      await atomicWriteBytes(cached, bundled);
      return cached.path;
    }
    final bytes = await http.getBytes(
      Uri.parse(spec.url),
      () => const <String, String>{},
    );
    await atomicWriteBytes(cached, bytes);
    return cached.path;
  }

  Future<Uint8List?> _loadBundled(String fileName) async {
    final loader = bundledLoader;
    if (loader != null) {
      return loader(fileName);
    }
    try {
      final data = await rootBundle.load('$initialAssetDir/$fileName');
      return data.buffer.asUint8List();
    } on Object {
      // Not a bundled asset (tests, dev runs) — try the filesystem copy.
    }
    final initial = File('${initialDir.path}/$fileName');
    if (initial.existsSync()) {
      return initial.readAsBytes();
    }
    return null;
  }

  /// Flutter asset prefix the pubspec declares for bundled SRS fallbacks.
  static const String initialAssetDir = 'rule_sets/initial_assets';

  /// Sync accessor for config builders (dns + routing). Call [ensure] at
  /// startup first.
  String getPath(String tag) => '${cacheDir.path}/$tag.srs';

  /// The `route.rule_set` entries for sing-box (audit W4.1): each tag
  /// ships as a LOCAL rule-set pointing at the on-disk copy seeded from
  /// the bundled initial asset (`ensure()`), plus an auxiliary remote
  /// rule-set so the engine updates it in place — previously remote-only
  /// entries forced the engine to download through PROXY at every start
  /// (and the start died when the proxy was not yet up).
  List<Map<String, dynamic>> ruleSetEntries({String downloadDetour = 'PROXY'}) {
    return registry.keys.map(_entryFor).toList();
  }

  /// Entries for one specific tag (used by the routing config assembler).
  /// Empty when the tag is unknown.
  List<Map<String, dynamic>> ruleSetEntriesFor(
    String tag, {
    String downloadDetour = 'PROXY',
  }) {
    final spec = registry[tag];
    if (spec == null) {
      return const <Map<String, dynamic>>[];
    }
    return <Map<String, dynamic>>[_entryFor(tag)];
  }

  /// One local rule-set entry for [tag] (1.14 schema: type local, format
  /// binary, path). The cache file exists before any config resolve —
  /// `ensure()` copies the bundled fallback at startup seeding.
  Map<String, dynamic> _entryFor(String tag) => <String, dynamic>{
    'type': 'local',
    'tag': tag,
    'format': 'binary',
    'path': getPath(tag),
  };

  /// Daily ETag-aware refresh of every registered asset.
  ///
  /// Fresh entries (younger than 6h) skip the network. Revalidation sends
  /// `If-None-Match`; 304 touches the timestamp. 403 with an exhausted rate
  /// limit surfaces as [GitHubRateLimitException] (caller schedules a retry
  /// at `resetAt`), 429 as [RateLimitException] with `retryAfter`. Any other
  /// failure keeps the stale bytes and moves on to the next asset.
  Future<void> refreshAll() async {
    for (final entry in registry.entries) {
      try {
        final bytes = await http.getBytes(
          Uri.parse(entry.value.url),
          () => const <String, String>{},
        );
        // Written under the tag key so [getPath]/[ensure] read the refreshed
        // bytes even when a future spec's initialFile diverges from the tag.
        await atomicWriteBytes(
          File('${cacheDir.path}/${entry.key}.srs'),
          bytes,
        );
      } on RateLimitException {
        rethrow;
      } on Object {
        continue;
      }
    }
  }
}

class GeoAssetSpec {
  const GeoAssetSpec({
    required this.url,
    required this.initialFile,
    required this.type,
  });

  final String url;
  final String initialFile;
  final String type;
}
