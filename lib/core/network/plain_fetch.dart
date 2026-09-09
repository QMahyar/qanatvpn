import 'dart:io';
import 'dart:typed_data';

import 'http_cache.dart';

/// Default User-Agent: GitHub API rejects requests without one (403), so
/// every fetch identifies the app + version-less channel pointer. Callers
/// that set their own UA keep it (first-writer wins in [plainFetch]).
const String kDefaultUserAgent =
    'qanatvpn (+https://github.com/QMahyar/qanatvpn)';

/// Plain HTTP fetch with no cache semantics: the background updater and the
/// endpoint importer both want raw responses with status + headers.
Future<CachedResponse> plainFetch(Uri url, Map<String, String> headers) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.getUrl(url);
    if (!headers.keys.any((h) => h.toLowerCase() == 'user-agent')) {
      request.headers.add('User-Agent', kDefaultUserAgent);
    }
    headers.forEach((name, value) => request.headers.add(name, value));
    final response = await request.close();
    final body = await response.fold<List<int>>(
      <int>[],
      (acc, chunk) => acc..addAll(chunk),
    );
    final flatHeaders = <String, String>{};
    response.headers.forEach((name, values) {
      flatHeaders[name] = values.join(', ');
    });
    return CachedResponse(
      statusCode: response.statusCode,
      headers: flatHeaders,
      body: Uint8List.fromList(body),
    );
  } finally {
    client.close();
  }
}
