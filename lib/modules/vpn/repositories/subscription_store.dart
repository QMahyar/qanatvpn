import 'dart:convert';
import 'dart:io';

import '../../../core/persistence/atomic_write.dart';
import '../../../core/persistence/app_paths.dart';

/// A managed subscription (audit W2.5 / goal.md §9: ETag-24h refresh).
/// Imported URLs previously dissolved into an undifferentiated endpoint
/// list and were never re-fetched — node lists rotted within a day.
class Subscription {
  const Subscription({
    required this.url,
    required this.name,
    this.etag,
    this.lastRefresh,
  });

  final String url;
  final String name;

  /// Last-seen `ETag` response header; sent back as `If-None-Match`.
  final String? etag;

  final DateTime? lastRefresh;

  Subscription copyWith({String? etag, DateTime? lastRefresh}) {
    return Subscription(
      url: url,
      name: name,
      etag: etag ?? this.etag,
      lastRefresh: lastRefresh ?? this.lastRefresh,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'url': url,
    'name': name,
    'etag': etag,
    'lastRefresh': lastRefresh?.toIso8601String(),
  };

  static Subscription fromJson(Map<String, dynamic> doc) => Subscription(
    url: doc['url'] as String,
    name: doc['name'] as String? ?? doc['url'] as String,
    etag: doc['etag'] as String?,
    lastRefresh: DateTime.tryParse(doc['lastRefresh'] as String? ?? ''),
  );
}

class SubscriptionStore {
  const SubscriptionStore({this.baseDir});

  final String? baseDir;

  List<Subscription> read() {
    try {
      final file = _file();
      if (!file.existsSync()) {
        return const <Subscription>[];
      }
      final doc = jsonDecode(file.readAsStringSync());
      if (doc is! List) {
        return const <Subscription>[];
      }
      return <Subscription>[
        for (final entry in doc.whereType<Map<String, dynamic>>())
          Subscription.fromJson(entry),
      ];
    } on Object {
      return const <Subscription>[];
    }
  }

  Future<void> save(List<Subscription> subscriptions) => atomicWriteString(
    _file(),
    jsonEncode(<Map<String, dynamic>>[
      for (final s in subscriptions) s.toJson(),
    ]),
  );

  /// Registers a URL (idempotent by URL — re-import refreshes the entry).
  Future<List<Subscription>> upsert(String url, {String? etag}) async {
    final current = read();
    final next = <Subscription>[
      for (final s in current)
        if (s.url != url) s,
      if (etag != null)
        Subscription(
          url: url,
          name: Uri.tryParse(url)?.host ?? url,
          etag: etag,
          lastRefresh: DateTime.now(),
        )
      else
        (current.where((s) => s.url == url).toList().isNotEmpty
            ? current.firstWhere((s) => s.url == url)
            : Subscription(
                url: url,
                name: Uri.tryParse(url)?.host ?? url,
              )),
    ];
    await save(next);
    return next;
  }

  Future<void> remove(String url) async {
    final current = read();
    await save(<Subscription>[
      for (final s in current)
        if (s.url != url) s,
    ]);
  }

  File _file() => File(
    baseDir != null
        ? '$baseDir/subscriptions.json'
        : '${defaultBaseDirSync()}/.yourvpn/subscriptions.json',
  );
}
