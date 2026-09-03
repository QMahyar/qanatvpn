import 'dart:io';
import 'dart:typed_data';

import 'http_cache.dart';

/// Plain HTTP fetch with no cache semantics: the background updater and the
/// endpoint importer both want raw responses with status + headers.
Future<CachedResponse> plainFetch(Uri url, Map<String, String> headers) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.getUrl(url);
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
