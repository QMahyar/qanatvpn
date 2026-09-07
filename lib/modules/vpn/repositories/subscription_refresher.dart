import 'dart:convert';

import '../../../core/network/http_cache.dart';
import '../../../core/network/plain_fetch.dart';
import 'subscription_store.dart';

/// Result of one subscription refresh cycle.
sealed class RefreshOutcome {
  const RefreshOutcome();
}

/// 200 with a new body: endpoints were re-imported by the caller.
class RefreshUpdated extends RefreshOutcome {
  const RefreshUpdated(this.body, this.etag);

  final String body;

  /// New ETag from the response; null when the server does not emit one.
  final String? etag;
}

/// 304 Not Modified (If-None-Match matched): nothing to do.
class RefreshNotModified extends RefreshOutcome {
  const RefreshNotModified();
}

class RefreshFailed extends RefreshOutcome {
  const RefreshFailed(this.message);

  final String message;
}

/// ETag-aware subscription fetch (goal.md §9): sends `If-None-Match` with
/// the stored ETag, treats 304 as a no-op, and returns the new body + ETag
/// on 200 so the caller re-imports and persists the cursor.
class SubscriptionRefresher {
  SubscriptionRefresher({Fetch? fetchImpl}) : _fetch = fetchImpl ?? plainFetch;

  final Fetch _fetch;

  Future<RefreshOutcome> refresh(Subscription subscription) async {
    final uri = Uri.tryParse(subscription.url);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      return RefreshFailed('not a fetchable URL: ${subscription.url}');
    }
    try {
      final headers = <String, String>{
        'Accept': '*/*',
        if (subscription.etag != null) 'If-None-Match': subscription.etag!,
      };
      final response = await _fetch(uri, headers);
      switch (response.statusCode) {
        case 304:
          return const RefreshNotModified();
        case 200:
          return RefreshUpdated(
            utf8.decode(response.body, allowMalformed: true),
            response.headers['etag'],
          );
        case 429:
          return RefreshFailed(
            'rate limited (retry-after: '
            '${response.headers['retry-after'] ?? 'unspecified'})',
          );
        default:
          return RefreshFailed('HTTP ${response.statusCode}');
      }
    } on Object catch (e) {
      return RefreshFailed(e.toString());
    }
  }
}
