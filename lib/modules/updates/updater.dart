import 'dart:convert';

import '../../core/network/http_cache.dart';

/// Parsed GitHub release + platform-aware asset selection.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.changelog,
    required this.assetUrl,
    required this.platformKey,
  });

  final String version;
  final String changelog;
  final String assetUrl;
  final String platformKey;

  bool isNewerThan(String localVersion) =>
      _semverKey(version).compareTo(_semverKey(localVersion)) > 0;
}

int _semverKey(String version) {
  final core = version.replaceFirst(RegExp(r'^v'), '').split('-').first;
  final parts = core.split('.');
  var key = 0;
  for (var i = 0; i < 3; i++) {
    key = key * 1000 + (i < parts.length ? int.tryParse(parts[i]) ?? 0 : 0);
  }
  return key;
}

/// Fetches the latest GitHub release, filters assets per platform, and maps
/// the `latest.json` platform schema (flutter_server_box / RecomBox style).
class UpdateFetcher {
  UpdateFetcher({required Fetch fetchImpl, this.repository = 'yourvpn/yourvpn'})
    : _fetch = fetchImpl;

  final Fetch _fetch;
  final String repository;

  /// Asset name fragments that identify this platform's installer.
  static const Map<String, List<String>> platformFilters = <String, List<String>>{
    'android-arm64': <String>['arm64-v8a', '.apk'],
    'android-arm': <String>['armeabi-v7a', '.apk'],
    'android-x64': <String>['x86_64', '.apk'],
    'windows-x64': <String>['windows-x64', '.zip'],
  };

  Future<UpdateInfo> latestFor(String platformKey) async {
    final filters = platformFilters[platformKey];
    if (filters == null) {
      throw ArgumentError('unknown platform: $platformKey');
    }
    final response = await _fetch(
      Uri.parse('https://api.github.com/repos/$repository/releases/latest'),
      const <String, String>{'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode == 403 &&
        response.headers['x-ratelimit-remaining'] == '0') {
      throw GitHubRateLimitException(
        resetAt: _parseReset(response.headers['x-ratelimit-reset']),
      );
    }
    if (response.statusCode == 429) {
      throw RateLimitException(
        retryAfter: _parseSeconds(response.headers['retry-after']),
      );
    }
    if (response.statusCode == 401) {
      throw const FormatException('GitHub rejected the request (401)');
    }
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode} fetching release');
    }
    final doc = jsonDecode(utf8.decode(response.body)) as Map<String, dynamic>;
    final version = doc['tag_name'] as String? ?? '0.0.0';
    final assets = doc['assets'] as List<dynamic>? ?? <dynamic>[];
    for (final asset in assets.whereType<Map<String, dynamic>>()) {
      final name = asset['name'] as String? ?? '';
      final url = asset['browser_download_url'] as String? ?? '';
      if (filters.every((f) => name.contains(f))) {
        return UpdateInfo(
          version: version,
          changelog: doc['body'] as String? ?? '',
          assetUrl: url,
          platformKey: platformKey,
        );
      }
    }
    throw const FormatException('no asset for this platform in latest release');
  }

  /// The `latest.json` platform map (mirrored to gh-pages for the in-app
  /// updater): {platform: {arch: url}}.
  Map<String, dynamic> latestJsonFromRelease(Map<String, dynamic> release) {
    final assets = release['assets'] as List<dynamic>? ?? <dynamic>[];
    final map = <String, dynamic>{};
    for (final entry in platformFilters.entries) {
      for (final asset in assets.whereType<Map<String, dynamic>>()) {
        final name = asset['name'] as String? ?? '';
        if (entry.value.every((f) => name.contains(f))) {
          map[entry.key] = <String, dynamic>{
            'url': asset['browser_download_url'],
            'version': release['tag_name'],
          };
          break;
        }
      }
    }
    return <String, dynamic>{'platforms': map, 'version': release['tag_name']};
  }

  DateTime? _parseReset(String? seconds) {
    final value = int.tryParse(seconds ?? '');
    if (value == null) {
      return null;
    }
    return DateTime.now().add(Duration(seconds: value));
  }

  Duration? _parseSeconds(String? seconds) {
    final value = int.tryParse(seconds ?? '');
    if (value == null) {
      return null;
    }
    return Duration(seconds: value);
  }
}

class HttpException implements Exception {
  const HttpException(this.message);

  final String message;

  @override
  String toString() => message;
}
