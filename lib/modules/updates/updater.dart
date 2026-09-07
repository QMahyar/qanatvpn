import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/network/http_cache.dart';
import '../../core/network/plain_fetch.dart';
import '../../core/persistence/app_paths.dart';
import '../../core/persistence/atomic_write.dart';

export '../../core/network/plain_fetch.dart' show plainFetch;

/// Parsed GitHub release + platform-aware asset selection.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.changelog,
    required this.assetUrl,
    required this.platformKey,
    this.sha256,
  });

  final String version;
  final String changelog;
  final String assetUrl;
  final String platformKey;

  /// Hex sha256 of the artifact when the release/mirror provides one. The
  /// installer fails closed when this and the sibling digest are both
  /// absent (audit W1.5).
  final String? sha256;

  UpdateInfo withSha256(String? sha256) =>
      UpdateInfo(version: version, changelog: changelog, assetUrl: assetUrl, platformKey: platformKey, sha256: sha256);

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
  UpdateFetcher({required Fetch fetchImpl, this.repository = 'QMahyar/yourvpn'})
    : _fetch = fetchImpl;

  final Fetch _fetch;
  final String repository;

  /// Asset name fragments that identify this platform's installer.
  static const Map<String, List<String>> platformFilters =
      <String, List<String>>{
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
    if (response.statusCode == 403) {
      if (response.headers['x-ratelimit-remaining'] == '0') {
        throw GitHubRateLimitException(
          resetAt: _parseReset(response.headers['x-ratelimit-reset']),
        );
      }
      // Audit W3.4: a plain 403 (blocked, forbidden, bad token) previously
      // fell through to the no-asset path and the controller read it as
      // 'no update'. Surface it honestly.
      throw const HttpException('GitHub returned 403 for the release API');
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
        // Prefer a digest carried in the release body's `<asset>: <hex>`
        // line for this asset; CI also attaches sibling `.sha256` files
        // which the installer probes at download time.
        final digest = _digestForAsset(doc['body'] as String? ?? '', name);
        return UpdateInfo(
          version: version,
          changelog: doc['body'] as String? ?? '',
          assetUrl: url,
          platformKey: platformKey,
          sha256: digest,
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

  /// Release-body convention (CI writes it): lines of
  /// `<asset-name>: <64-hex>` for the matching artifact. Null when absent.
  static String? _digestForAsset(String body, String assetName) {
    for (final line in body.split(RegExp(r'[\r\n]+'))) {
      final m = RegExp(
        '^\\s*${RegExp.escape(assetName)}\\s*[:=]\\s*([0-9a-fA-F]{64})\\s*'
        r'$',
      ).firstMatch(line);
      if (m != null) {
        return m.group(1)!.toLowerCase();
      }
    }
    return null;
  }

  DateTime? _parseReset(String? seconds) {
    final value = int.tryParse(seconds ?? '');
    if (value == null) {
      return null;
    }
    // GitHub sends an absolute epoch timestamp, not a relative offset
    // (same parse as http_cache.dart).
    return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
  }

  Duration? _parseSeconds(String? seconds) {
    final value = int.tryParse(seconds ?? '');
    if (value == null) {
      return null;
    }
    return Duration(seconds: value);
  }
}

/// Where the app's own update metadata comes from on this platform:
/// the GitHub API when online, the `latest.json` mirror (gh-pages) as
/// fallback, since the mirror is written by the release pipeline after all
/// platform assets are attached (single producer — see workflows).
class UpdateSource {
  UpdateSource({required this.fetchImpl, this.mirrorUrl});

  /// Production default for [mirrorUrl]: the gh-pages mirror written by the
  /// release pipeline (single producer). Tests pass their own or none.
  static const String defaultMirrorUrl =
      'https://qmahyar.github.io/yourvpn/latest.json';

  final Fetch fetchImpl;

  /// `https://<org>.github.io/<repo>/latest.json` once the site is live.
  final String? mirrorUrl;

  Future<UpdateInfo?> latestFor(String platformKey) async {
    try {
      return await _fromApi(platformKey);
    } on Object {
      final mirrored = await _fromMirror(platformKey);
      if (mirrored != null) {
        return mirrored;
      }
      rethrow;
    }
  }

  Future<UpdateInfo?> _fromApi(String platformKey) async {
    final fetcher = UpdateFetcher(fetchImpl: fetchImpl);
    return fetcher.latestFor(platformKey);
  }

  /// Mirror format: {version, platforms: {key: {url, version}}}. No changelog
  /// in the mirror, so the changelog field stays empty and the API is retried
  /// on the next daily pass for the body.
  Future<UpdateInfo?> _fromMirror(String platformKey) async {
    final url = mirrorUrl;
    if (url == null) {
      return null;
    }
    try {
      final response = await fetchImpl(
        Uri.parse(url),
        const <String, String>{},
      );
      if (response.statusCode != 200) {
        return null;
      }
      final doc =
          jsonDecode(utf8.decode(response.body)) as Map<String, dynamic>;
      final platforms = doc['platforms'] as Map<String, dynamic>? ?? const {};
      final entry = platforms[platformKey] as Map<String, dynamic>?;
      if (entry == null) {
        return null;
      }
      return UpdateInfo(
        version:
            (entry['version'] as String?) ?? doc['version'] as String? ?? '',
        changelog: '',
        assetUrl: entry['url'] as String? ?? '',
        platformKey: platformKey,
        sha256: (entry['sha256'] as String?),
      );
    } on Object {
      return null;
    }
  }
}

/// Resolves the platform key used for asset filtering. [androidAbi] is a
/// seam, not a production input — no caller supplies it today (universal-
/// APK releases make arm64 the correct default; wire Android abiList into
/// the dispatcher when per-ABI splits land). [onAndroid] pins the host
/// check for tests (CI runs on Ubuntu, so the Android branch is only
/// reachable through this seam). Unknown ABIs throw instead of silently
/// choosing arm64; an unknown OS still throws so a stray desktop harness
/// never fetches phone APKs.
String resolvePlatformKey({String? androidAbi, bool? onAndroid}) {
  final android = onAndroid ?? Platform.isAndroid;
  if (android) {
    return switch (androidAbi) {
      'armeabi-v7a' => 'android-arm',
      'x86_64' => 'android-x64',
      'arm64-v8a' => 'android-arm64',
      null => 'android-arm64',
      // x86 (32-bit) has no APK in the release matrix — fail loudly rather
      // than route an x64 APK the device cannot install.
      _ => throw ArgumentError('unsupported Android ABI: $androidAbi'),
    };
  }
  if (Platform.isWindows) {
    return 'windows-x64';
  }
  throw UnsupportedError('updates unsupported on ${Platform.operatingSystem}');
}

/// Where the last check result lives: a JSON file both the UI isolate and
/// the workmanager background isolate can reach. No plugin dependency, no
/// provider override ceremony — read renders, write updates.
class UpdateStore {
  const UpdateStore({this.baseDir});

  final String? baseDir;

  Future<void> save(UpdateInfo info, String localVersion) async {
    await atomicWriteString(
      _file(),
      jsonEncode(<String, dynamic>{
        'version': info.version,
        'changelog': info.changelog,
        'assetUrl': info.assetUrl,
        'platformKey': info.platformKey,
        'sha256': info.sha256,
        'localVersion': localVersion,
        'checkedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  UpdateInfo? read() {
    try {
      final file = _file();
      if (!file.existsSync()) {
        return null;
      }
      return _decodeStoredUpdate(file.readAsStringSync());
    } on Object {
      return null;
    }
  }

  /// Full envelope including the local version seen at check time — the
  /// restart comparison needs both halves (see [StoredUpdate]).
  StoredUpdate? readStored() {
    try {
      final file = _file();
      if (!file.existsSync()) {
        return null;
      }
      return decodeStoredUpdate(file.readAsStringSync());
    } on Object {
      return null;
    }
  }

  DateTime? lastCheckedAt() {
    try {
      final file = _file();
      if (!file.existsSync()) {
        return null;
      }
      final doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return DateTime.tryParse(doc['checkedAt'] as String? ?? '');
    } on Object {
      return null;
    }
  }

  File _file() => File(
    baseDir != null
        ? '$baseDir/last_update_check.json'
        : '${defaultBaseDirSync()}/.yourvpn/last_update_check.json',
  );
}

UpdateInfo? _decodeStoredUpdate(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  try {
    final doc = jsonDecode(raw) as Map<String, dynamic>;
    return UpdateInfo(
      version: doc['version'] as String,
      changelog: doc['changelog'] as String? ?? '',
      assetUrl: doc['assetUrl'] as String? ?? '',
      platformKey: doc['platformKey'] as String? ?? '',
      sha256: doc['sha256'] as String?,
    );
  } on Object {
    return null;
  }
}

/// What [UpdateStore] persists: the remote [UpdateInfo] plus the local
/// version seen at check time. Persisting both is what lets a restart
/// distinguish "update found" from "checked, already current" — reading
/// only the remote half made every check render Available forever.
class StoredUpdate {
  const StoredUpdate({required this.info, required this.localVersion});

  final UpdateInfo info;
  final String localVersion;

  bool get isNewerThanLocal => info.isNewerThan(localVersion);
}

StoredUpdate? decodeStoredUpdate(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  try {
    final doc = jsonDecode(raw) as Map<String, dynamic>;
    return StoredUpdate(
      info: UpdateInfo(
        version: doc['version'] as String,
        changelog: doc['changelog'] as String? ?? '',
        assetUrl: doc['assetUrl'] as String? ?? '',
        platformKey: doc['platformKey'] as String? ?? '',
        sha256: doc['sha256'] as String?,
      ),
      localVersion: doc['localVersion'] as String? ?? '',
    );
  } on Object {
    return null;
  }
}

/// Callback entry point for workmanager's background isolate. Top-level +
/// entry-point annotated so the dispatcher survives tree shaking.
///
/// [localVersion] comes from the UI isolate (package_info_plus) via the
/// dispatcher's `inputData`; the background isolate avoids the plugin
/// channel. An empty value means "unknown" — the store keeps the remote
/// info and restart comparison shows the artifact rather than a false
/// "up to date" (see UpdateController.build).
@pragma('vm:entry-point')
Future<bool> updateCheckBackgroundTask({String? localVersion}) async {
  try {
    // Background isolate: startup wiring did not run here, so resolve the
    // store directory via path_provider before any file IO (audit W1.4:
    // the env-var chain is unset on Android and the temp fallback is
    // unreadable).
    await resolveAppSupportDir();
    final platformKey = resolvePlatformKey();
    final source = UpdateSource(
      fetchImpl: plainFetch,
      mirrorUrl: UpdateSource.defaultMirrorUrl,
    );
    final info = await source.latestFor(platformKey);
    if (info == null) {
      return true;
    }
    await const UpdateStore().save(info, localVersion ?? '');
    return true;
  } on Object {
    return false;
  }
}

class HttpException implements Exception {
  const HttpException(this.message);

  final String message;

  @override
  String toString() => message;
}
