import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:qanatvpn/core/network/http_cache.dart';
import 'package:qanatvpn/main.dart' show subscriptionsRefreshWithStores;
import 'package:qanatvpn/modules/vpn/repositories/endpoint_store.dart';
import 'package:qanatvpn/modules/vpn/repositories/ingestion/normalized_endpoint.dart';
import 'package:qanatvpn/modules/vpn/repositories/subscription_refresher.dart';
import 'package:qanatvpn/modules/vpn/repositories/subscription_store.dart';

/// Audit W2.5 / goal.md §9: managed subscriptions with ETag-24h refresh.
/// URLs were one-shot imports that never refreshed before.
void main() {
  group('SubscriptionStore', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('qanatvpn-substore');
    });

    tearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    test('empty until first upsert; upsert is idempotent by URL', () async {
      final store = SubscriptionStore(baseDir: dir.path);
      expect(store.read(), isEmpty);

      await store.upsert('https://sub.example.com/a');
      expect(store.read(), hasLength(1));

      // Second upsert of the same URL does not duplicate.
      await store.upsert('https://sub.example.com/a');
      final after = store.read();
      expect(after, hasLength(1));
      expect(after.single.name, 'sub.example.com');
    });

    test('upsert with etag stores the cursor and lastRefresh', () async {
      final store = SubscriptionStore(baseDir: dir.path);
      await store.upsert('https://sub.example.com/a', etag: '"abc123"');
      final sub = store.read().single;
      expect(sub.etag, '"abc123"');
      expect(sub.lastRefresh, isNotNull);
    });

    test('round-trips through disk (restart simulation)', () async {
      final store = SubscriptionStore(baseDir: dir.path);
      await store.upsert('https://sub.example.com/a', etag: '"e1"');
      await store.upsert('https://sub.example.com/b');

      final reread = SubscriptionStore(baseDir: dir.path).read();
      expect(reread, hasLength(2));
      expect(
        reread.firstWhere((s) => s.url.endsWith('/a')).etag,
        '"e1"',
      );
    });

    test('remove drops only the named subscription', () async {
      final store = SubscriptionStore(baseDir: dir.path);
      await store.upsert('https://sub.example.com/a');
      await store.upsert('https://sub.example.com/b');
      await store.remove('https://sub.example.com/a');
      final left = store.read();
      expect(left, hasLength(1));
      expect(left.single.url, 'https://sub.example.com/b');
    });
  });

  group('SubscriptionRefresher', () {
    late HttpServer server;
    late int port;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      port = server.port;
    });

    tearDown(() => server.close(force: true));

    test('200 with body + ETag returns RefreshUpdated', () async {
      server.listen((request) async {
        expect(request.headers.value('if-none-match'), isNull);
        request.response.headers.set('etag', '"v2"');
        request.response.write('vless://u@h:443?a=x#n1');
        await request.response.close();
      });
      final outcome = await SubscriptionRefresher().refresh(
        Subscription(url: 'http://127.0.0.1:$port/sub', name: 't'),
      );
      expect(outcome, isA<RefreshUpdated>());
      final updated = outcome as RefreshUpdated;
      expect(updated.etag, '"v2"');
      expect(updated.body, contains('vless://'));
    });

    test('304 on If-None-Match match returns RefreshNotModified', () async {
      server.listen((request) async {
        expect(request.headers.value('if-none-match'), '"v2"');
        request.response.statusCode = 304;
        await request.response.close();
      });
      final outcome = await SubscriptionRefresher().refresh(
        Subscription(
          url: 'http://127.0.0.1:$port/sub',
          name: 't',
          etag: '"v2"',
        ),
      );
      expect(outcome, isA<RefreshNotModified>());
    });

    test('429 surfaces as RefreshFailed with retry-after', () async {
      server.listen((request) async {
        request.response.statusCode = 429;
        request.response.headers.set('retry-after', '600');
        await request.response.close();
      });
      final outcome = await SubscriptionRefresher().refresh(
        Subscription(url: 'http://127.0.0.1:$port/sub', name: 't'),
      );
      expect(outcome, isA<RefreshFailed>());
      expect((outcome as RefreshFailed).message, contains('600'));
    });

    test('non-HTTP URL fails without touching the network', () async {
      final outcome = await SubscriptionRefresher().refresh(
        const Subscription(url: 'ftp://x', name: 't'),
      );
      expect(outcome, isA<RefreshFailed>());
    });

    test('cleartext http URL refused (W3.4), loopback allowed', () async {
      // Public http://: credentials-bearing body must not travel cleartext.
      final refused = await SubscriptionRefresher().refresh(
        const Subscription(url: 'http://sub.example.com/x', name: 't'),
      );
      expect(refused, isA<RefreshFailed>());
      expect((refused as RefreshFailed).message, contains('https'));

      // Loopback stays allowed for tests/dev (scheme check passes; the
      // server 404s, which is a RefreshFailed but not an https refusal).
      server.listen((request) async {
        request.response.statusCode = 404;
        await request.response.close();
      });
      final ok = await SubscriptionRefresher().refresh(
        Subscription(url: 'http://127.0.0.1:$port/sub', name: 't'),
      );
      expect(
        (ok as RefreshFailed).message,
        isNot(contains('https')),
      );
    });

    test('connection refused is RefreshFailed, not a thrown error', () async {
      final outcome = await SubscriptionRefresher().refresh(
        const Subscription(url: 'http://127.0.0.1:1/sub', name: 't'),
      );
      expect(outcome, isA<RefreshFailed>());
    });
  });

  group('background refresh task (testable core)', () {
    late Directory dir;
    late EndpointStore endpointStore;
    late SubscriptionStore subscriptionStore;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('qanatvpn-subtask');
      endpointStore = EndpointStore(baseDir: dir.path);
      subscriptionStore = SubscriptionStore(baseDir: dir.path);
    });

    tearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    StoredEndpoint trojan(String tag) => StoredEndpoint(
      endpoint: TrojanEndpoint(tag: tag, address: 'a', port: 443, password: 'p'),
      label: tag,
    );

    test('empty subscription list is a successful no-op', () async {
      final ok = await subscriptionsRefreshWithStores(
        subscriptionStore: subscriptionStore,
        endpointStore: endpointStore,
      );
      expect(ok, isTrue);
      expect(endpointStore.read(), isEmpty);
    });

    test('304 refresh keeps endpoints and persists the cursor', () async {
      await subscriptionStore.upsert('https://sub.example.com/y', etag: '"v1"');
      await endpointStore.save(<StoredEndpoint>[trojan('existing')]);

      final ok = await subscriptionsRefreshWithStores(
        subscriptionStore: subscriptionStore,
        endpointStore: endpointStore,
        refresher: SubscriptionRefresher(
          fetchImpl: (url, headers) async {
            expect(headers['If-None-Match'], '"v1"');
            return CachedResponse(
              statusCode: 304,
              headers: const <String, String>{},
              body: Uint8List(0),
            );
          },
        ),
      );
      expect(ok, isTrue);
      expect(endpointStore.read().single.tag, 'existing');
    });

    test('200 refresh merges new nodes into the endpoint store', () async {
      await subscriptionStore.upsert('https://sub.example.com/y', etag: '"v1"');

      final ok = await subscriptionsRefreshWithStores(
        subscriptionStore: subscriptionStore,
        endpointStore: endpointStore,
        refresher: SubscriptionRefresher(
          fetchImpl: (url, headers) async => CachedResponse(
            statusCode: 200,
            headers: const <String, String>{'etag': '"v2"'},
            body: Uint8List.fromList(
              utf8.encode('trojan://pw@srv.example.com:443#fresh-node'),
            ),
          ),
        ),
      );
      expect(ok, isTrue);
      final endpoints = endpointStore.read();
      expect(endpoints, hasLength(1));
      expect(endpoints.single.tag, 'fresh-node');
      expect(endpoints.single.sourceUrl, 'https://sub.example.com/y');
      // ETag cursor advanced.
      expect(subscriptionStore.read().single.etag, '"v2"');
    });

    test('dead subscription does not fail the job', () async {
      await subscriptionStore.upsert('http://dead/x');
      final ok = await subscriptionsRefreshWithStores(
        subscriptionStore: subscriptionStore,
        endpointStore: endpointStore,
        refresher: SubscriptionRefresher(
          fetchImpl: (url, headers) async => CachedResponse(
            statusCode: 500,
            headers: const <String, String>{},
            body: Uint8List(0),
          ),
        ),
      );
      expect(ok, isTrue);
    });
  });
}
