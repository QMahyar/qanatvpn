import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Rate-limit / ETag aware HTTP cache for asset downloads.
///
/// Wraps a fetch function with: `If-None-Match` revalidation, GitHub `403` +
/// `x-ratelimit-remaining: 0` → [GitHubRateLimitException] carrying
/// `x-ratelimit-reset`, `429` → [RateLimitException] honoring `retry-after`,
/// and stale-while-revalidate within [staleAfter] (stale body still served
/// when the network dies).
typedef Fetch =
    Future<CachedResponse> Function(Uri url, Map<String, String> headers);

class HttpCache {
  HttpCache({
    required this.fetch,
    this.cacheDir,
    this.staleAfter = const Duration(hours: 6),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Fetch fetch;
  final Directory? cacheDir;
  final Duration staleAfter;
  final DateTime Function() _now;

  final Map<Uri, _CacheEntry> _memory = <Uri, _CacheEntry>{};

  /// Fresh cache wins; stale cache revalidates (`If-None-Match`); 304
  /// refreshes the timestamp; network death serves the stale body.
  Future<Uint8List> getBytes(
    Uri url,
    Map<String, String> Function() headers,
  ) async {
    final entry = _memory[url] ?? await _readDisk(url);
    final isStale =
        entry == null || _now().difference(entry.fetchedAt) > staleAfter;

    if (entry != null && !isStale) {
      return entry.body;
    }

    final requestHeaders = <String, String>{...headers()};
    if (entry?.etag != null) {
      requestHeaders['If-None-Match'] = entry!.etag!;
    }

    try {
      final response = await fetch(url, requestHeaders);
      if (response.statusCode == 304 && entry != null) {
        final refreshed = _CacheEntry(
          body: entry.body,
          etag: entry.etag,
          fetchedAt: _now(),
        );
        _memory[url] = refreshed;
        await _writeDisk(url, refreshed);
        return refreshed.body;
      }
      if (response.statusCode == 403 &&
          response.headers['x-ratelimit-remaining'] == '0') {
        throw GitHubRateLimitException(
          resetAt: _parseReset(response.headers['x-ratelimit-reset']),
        );
      }
      if (response.statusCode == 429) {
        throw RateLimitException(
          retryAfter: _parseDuration(response.headers['retry-after']),
        );
      }
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode} for $url');
      }
      final fresh = _CacheEntry(
        body: response.body,
        etag: response.headers['etag'],
        fetchedAt: _now(),
      );
      _memory[url] = fresh;
      await _writeDisk(url, fresh);
      return fresh.body;
    } on GitHubRateLimitException {
      rethrow;
    } on RateLimitException {
      rethrow;
    } on Object {
      if (entry != null) {
        return entry.body;
      }
      rethrow;
    }
  }

  Future<_CacheEntry?> _readDisk(Uri url) async {
    final dir = cacheDir;
    if (dir == null) {
      return null;
    }
    final metaFile = File('${dir.path}/${_key(url)}.meta.json');
    final bodyFile = File('${dir.path}/${_key(url)}.body');
    if (!metaFile.existsSync() || !bodyFile.existsSync()) {
      return null;
    }
    try {
      final meta = jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
      final entry = _CacheEntry(
        body: bodyFile.readAsBytesSync(),
        etag: meta['etag'] as String?,
        fetchedAt: DateTime.parse(meta['fetchedAt'] as String),
      );
      _memory[url] = entry;
      return entry;
    } on Object {
      return null;
    }
  }

  Future<void> _writeDisk(Uri url, _CacheEntry entry) async {
    final dir = cacheDir;
    if (dir == null) {
      return;
    }
    await dir.create(recursive: true);
    final key = _key(url);
    await File('${dir.path}/$key.meta.json').writeAsString(
      jsonEncode(<String, dynamic>{
        'etag': entry.etag,
        'fetchedAt': entry.fetchedAt.toIso8601String(),
      }),
    );
    await File('${dir.path}/$key.body').writeAsBytes(entry.body);
  }

  String _key(Uri url) =>
      base64Url.encode(utf8.encode(url.toString())).replaceAll('=', '');

  DateTime? _parseReset(String? seconds) {
    final value = int.tryParse(seconds ?? '');
    if (value == null) {
      return null;
    }
    // GitHub sends an absolute epoch timestamp, not a relative offset.
    return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
  }

  Duration? _parseDuration(String? seconds) {
    final value = int.tryParse(seconds ?? '');
    if (value == null) {
      return null;
    }
    return Duration(seconds: value);
  }
}

class _CacheEntry {
  const _CacheEntry({
    required this.body,
    required this.fetchedAt,
    this.etag,
  });

  final Uint8List body;
  final String? etag;
  final DateTime fetchedAt;
}

class RateLimitException implements Exception {
  RateLimitException({required this.retryAfter});

  final Duration? retryAfter;

  @override
  String toString() => 'rate limited, retry after ${retryAfter ?? 'unknown'}';
}

class GitHubRateLimitException extends RateLimitException {
  GitHubRateLimitException({required this.resetAt})
    : super(retryAfter: resetAt?.difference(DateTime.now()));

  final DateTime? resetAt;
}

class CachedResponse {
  const CachedResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final Map<String, String> headers;
  final Uint8List body;
}
