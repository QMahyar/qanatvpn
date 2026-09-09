import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../core/network/http_cache.dart' show Fetch;
import '../../core/network/plain_fetch.dart';

/// Download-and-verify pipeline for update artifacts (audit W1.5: update
/// artifacts were installed with zero integrity checks — CI-generated
/// sha256 files were never consulted).
///
/// Flow: download asset to a temp file → obtain the expected sha256 →
/// compare → only then hand the verified file to the platform installer.
/// Any mismatch or missing digest fails closed.
class UpdateVerifier {
  UpdateVerifier({Fetch? fetchImpl}) : _fetch = fetchImpl ?? plainFetch;

  final Fetch _fetch;

  /// Downloads [assetUrl] and verifies it against [expectedSha256] (hex).
  /// Returns the verified temp file; the caller owns cleanup.
  ///
  /// [expectedSha256] may be null only when [digestResolver] is provided —
  /// resolver failure then fails closed. A null digest with no resolver
  /// throws: installing an unverifiable artifact is exactly the hole this
  /// class closes.
  Future<File> downloadVerified(
    Uri assetUrl,
    String? expectedSha256, {
    Future<String?> Function()? digestResolver,
    Directory? targetDir,
    void Function(int received, int? total)? onProgress,
  }) async {
    final digest =
        expectedSha256 ??
        (digestResolver != null ? await digestResolver() : null);
    final normalized = digest?.toLowerCase();
    if (normalized == null || normalized.length != 64) {
      throw const VerifyException(
        'no sha256 digest available for this artifact — refusing to install',
      );
    }
    final file = await _download(assetUrl, onProgress, targetDir);
    try {
      final actual = await _sha256OfFile(file);
      if (actual != normalized) {
        throw VerifyException(
          'sha256 mismatch: expected $digest got $actual',
        );
      }
      return file;
    } on Object {
      try {
        await file.delete();
      } on Object {
        // Best-effort cleanup of a rejected artifact.
      }
      rethrow;
    }
  }

  /// Resolves the expected digest for an asset URL by probing sibling
  /// `<asset>.sha256` files. Accepts a bare hex line or the
  /// `<sha256>  <filename>` format `sha256sum` emits. Returns null when
  /// the sibling is absent — callers decide whether that fails closed.
  Future<String?> siblingDigest(Uri assetUrl) async {
    final sibling = assetUrl.replace(path: '${assetUrl.path}.sha256');
    try {
      final response = await _fetch(sibling, const <String, String>{});
      if (response.statusCode != 200) {
        return null;
      }
      return parseDigestFile(utf8.decode(response.body));
    } on Object {
      return null;
    }
  }

  Future<File> _download(
    Uri url,
    void Function(int received, int? total)? onProgress,
    Directory? targetDir,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(url);
      request.headers.add('User-Agent', kDefaultUserAgent);
      final response = await request.close();
      if (response.statusCode != 200) {
        throw VerifyException('download failed: HTTP ${response.statusCode}');
      }
      final tempDir = targetDir ?? Directory.systemTemp;
      final file = File(
        '${tempDir.path}${Platform.pathSeparator}'
        'qanatvpn_update_${DateTime.now().millisecondsSinceEpoch}_${url.pathSegments.last}',
      );
      final sink = file.openWrite();
      var received = 0;
      final total = response.contentLength > 0 ? response.contentLength : null;
      await for (final chunk in response) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();
      return file;
    } finally {
      client.close();
    }
  }

  Future<String> _sha256OfFile(File file) async {
    final bytes = await file.readAsBytes();
    final Hash hash = await Sha256().hash(bytes);
    return _hexEncode(Uint8List.fromList(hash.bytes));
  }

  static String _hexEncode(List<int> bytes) {
    const digits = '0123456789abcdef';
    final out = StringBuffer();
    for (final b in bytes) {
      out.write(digits[(b >> 4) & 0xf]);
      out.write(digits[b & 0xf]);
    }
    return out.toString();
  }

  /// Extracts the hex digest from a `.sha256` payload: bare hex, or the
  /// `<digest>  <name>` sha256sum format, or `digest = name` BSD style.
  static String? parseDigestFile(String raw) {
    for (final line in raw.split(RegExp(r'[\r\n]+'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final match = RegExp(
        r'^([0-9a-fA-F]{64})\b',
      ).firstMatch(trimmed);
      if (match != null) {
        return match.group(1)!.toLowerCase();
      }
    }
    return null;
  }
}

class VerifyException implements Exception {
  const VerifyException(this.message);

  final String message;

  @override
  String toString() => message;
}
