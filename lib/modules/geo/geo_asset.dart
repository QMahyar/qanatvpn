import 'dart:io';

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
  });

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
    final initial = File('${initialDir.path}/${spec.initialFile}');
    if (initial.existsSync()) {
      await initial.copy(cached.path);
      return cached.path;
    }
    final bytes = await http.getBytes(
      Uri.parse(spec.url),
      () => const <String, String>{},
    );
    await atomicWriteBytes(cached, bytes);
    return cached.path;
  }

  /// Sync accessor for config builders (dns + routing). Call [ensure] at
  /// startup first.
  String getPath(String tag) => '${cacheDir.path}/$tag.srs';

  /// The `route.rule_set` entries for sing-box: remote binary, proxy detour,
  /// daily update interval.
  List<Map<String, dynamic>> ruleSetEntries({String downloadDetour = 'PROXY'}) {
    return registry.keys.map((tag) {
      return <String, dynamic>{
        'type': 'remote',
        'tag': tag,
        'format': 'binary',
        'url': registry[tag]!.url,
        'download_detour': downloadDetour,
        'update_interval': '24h',
      };
    }).toList();
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
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'remote',
        'tag': tag,
        'format': 'binary',
        'url': spec.url,
        'download_detour': downloadDetour,
        'update_interval': '24h',
      },
    ];
  }

  /// Daily ETag-aware refresh of every registered asset.
  ///
  /// Fresh entries (younger than 6h) skip the network. Revalidation sends
  /// `If-None-Match`; 304 touches the timestamp. 403 with an exhausted rate
  /// limit surfaces as [GitHubRateLimitException] (caller schedules a retry
  /// at `resetAt`), 429 as [RateLimitException] with `retryAfter`. Any other
  /// failure keeps the stale bytes and moves on to the next asset.
  Future<void> refreshAll() async {
    for (final spec in registry.values) {
      try {
        final bytes = await http.getBytes(
          Uri.parse(spec.url),
          () => const <String, String>{},
        );
        await atomicWriteBytes(
          File('${cacheDir.path}/${spec.initialFile}'),
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
