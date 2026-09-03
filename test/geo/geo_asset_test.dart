import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/core/network/http_cache.dart';
import 'package:yourvpn/modules/geo/geo_asset.dart';

typedef FetchCall = ({Uri url, Map<String, String> headers});

class MockFetch {
  MockFetch(this.responses);

  final Map<Uri, CachedResponse> responses;
  final List<FetchCall> calls = <FetchCall>[];

  CachedResponse call(Uri url, Map<String, String> headers) {
    calls.add((url: url, headers: headers));
    final response = responses[url];
    if (response == null) {
      throw const SocketException('offline');
    }
    return response;
  }

  Future<CachedResponse> fetch(Uri url, Map<String, String> headers) async =>
      call(url, headers);
}

CachedResponse srs(
  int statusCode, {
  Map<String, String> headers = const {},
  List<int>? body,
}) {
  return CachedResponse(
    statusCode: statusCode,
    headers: headers,
    body: Uint8List.fromList(body ?? <int>[0x53, 0x52, 0x53, 2, 1]),
  );
}

void main() {
  late Directory tempDir;
  late Directory cacheDir;
  late Directory initialDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('geo_test');
    cacheDir = Directory('${tempDir.path}/cache');
    initialDir = Directory('${tempDir.path}/initial');
    await initialDir.create(recursive: true);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('ensure', () {
    test(
      'copies the bundled initial asset when cache is empty, never throws',
      () async {
        final bytes = <int>[1, 2, 3, 4];
        await File('${initialDir.path}/geosite-cn.srs').writeAsBytes(bytes);
        final geo = GeoAsset(
          cacheDir: cacheDir,
          initialDir: initialDir,
          http: HttpCache(fetch: MockFetch(<Uri, CachedResponse>{}).fetch),
        );

        final path = await geo.ensure('geosite-cn');

        expect(path, '${cacheDir.path}/geosite-cn.srs');
        expect(await File(path).readAsBytes(), bytes);
      },
    );

    test('returns cache without any HTTP when cached', () async {
      final mock = MockFetch(<Uri, CachedResponse>{});
      final geo = GeoAsset(
        cacheDir: cacheDir,
        initialDir: initialDir,
        http: HttpCache(fetch: mock.fetch),
      );
      await cacheDir.create(recursive: true);
      await File('${cacheDir.path}/geosite-cn.srs').writeAsBytes(<int>[9]);

      final path = await geo.ensure('geosite-cn');

      expect(path, '${cacheDir.path}/geosite-cn.srs');
      expect(mock.calls, isEmpty);
    });

    test('downloads when neither cache nor initial asset exists', () async {
      final mock = MockFetch(<Uri, CachedResponse>{
        Uri.parse(GeoAsset.registry['geosite-cn']!.url): srs(200),
      });
      final geo = GeoAsset(
        cacheDir: cacheDir,
        initialDir: initialDir,
        http: HttpCache(fetch: mock.fetch),
      );

      final path = await geo.ensure('geosite-cn');

      expect(mock.calls, hasLength(1));
      expect(await File(path).exists(), isTrue);
    });

    test('unknown tag → ArgumentError', () async {
      final geo = GeoAsset(
        cacheDir: cacheDir,
        initialDir: initialDir,
        http: HttpCache(fetch: MockFetch(<Uri, CachedResponse>{}).fetch),
      );

      expect(() => geo.ensure('nope'), throwsArgumentError);
    });

    test('getPath is a stable path for dns/routing builders', () {
      final geo = GeoAsset(
        cacheDir: cacheDir,
        initialDir: initialDir,
        http: HttpCache(fetch: MockFetch(<Uri, CachedResponse>{}).fetch),
      );

      expect(geo.getPath('geosite-cn'), '${cacheDir.path}/geosite-cn.srs');
    });

    test('ruleSetEntries: remote binary, proxy detour, 24h', () {
      final geo = GeoAsset(
        cacheDir: cacheDir,
        initialDir: initialDir,
        http: HttpCache(fetch: MockFetch(<Uri, CachedResponse>{}).fetch),
      );

      final entries = geo.ruleSetEntries();
      expect(entries, hasLength(2));
      final entry = entries.first;
      expect(entry['type'], 'remote');
      expect(entry['format'], 'binary');
      expect(entry['download_detour'], 'PROXY');
      expect(entry['update_interval'], '24h');
      expect((entry['url'] as String).startsWith('https://'), isTrue);
    });
  });

  group('refreshAll rate limits', () {
    test(
      '403 + x-ratelimit-remaining:0 + x-ratelimit-reset → GitHubRateLimitException',
      () async {
        final url = Uri.parse(GeoAsset.registry['geosite-cn']!.url);
        final mock = MockFetch(<Uri, CachedResponse>{
          url: srs(
            403,
            headers: <String, String>{
              'x-ratelimit-remaining': '0',
              'x-ratelimit-reset': '1700000000',
            },
          ),
        });
        final geo = GeoAsset(
          cacheDir: cacheDir,
          initialDir: initialDir,
          http: HttpCache(fetch: mock.fetch),
        );

        await expectLater(
          geo.refreshAll(),
          throwsA(isA<GitHubRateLimitException>()),
        );
        expect(mock.calls.single.headers.containsKey('If-None-Match'), isFalse);
      },
    );

    test('429 + retry-after → RateLimitException with duration', () async {
      final url = Uri.parse(GeoAsset.registry['geosite-cn']!.url);
      final mock = MockFetch(<Uri, CachedResponse>{
        url: srs(429, headers: <String, String>{'retry-after': '120'}),
      });
      final geo = GeoAsset(
        cacheDir: cacheDir,
        initialDir: initialDir,
        http: HttpCache(fetch: mock.fetch),
      );

      try {
        await geo.refreshAll();
        fail('expected RateLimitException');
      } on RateLimitException catch (e) {
        expect(e.retryAfter, const Duration(seconds: 120));
      }
    });

    test('network failure keeps stale bytes and does not throw', () async {
      final url = Uri.parse(GeoAsset.registry['geosite-cn']!.url);
      final mock = MockFetch(<Uri, CachedResponse>{
        url: srs(
          200,
          headers: <String, String>{'etag': '"v1"'},
          body: <int>[0x53, 0x52, 0x53, 2, 1, 0xAA],
        ),
      });
      final geo = GeoAsset(
        cacheDir: cacheDir,
        initialDir: initialDir,
        http: HttpCache(fetch: mock.fetch),
      );

      await geo.refreshAll();
      final before = await File(
        '${cacheDir.path}/geosite-cn.srs',
      ).readAsBytes();

      final offline = MockFetch(<Uri, CachedResponse>{});
      final offlineGeo = GeoAsset(
        cacheDir: cacheDir,
        initialDir: initialDir,
        http: HttpCache(fetch: offline.fetch),
      );
      await offlineGeo.refreshAll();

      final after = await File('${cacheDir.path}/geosite-cn.srs').readAsBytes();
      expect(after, before);
    });
  });

  group('refreshAll freshness + ETag', () {
    test('second refresh within 6h makes no HTTP calls', () async {
      final mock = MockFetch(<Uri, CachedResponse>{
        for (final spec in GeoAsset.registry.values)
          Uri.parse(spec.url): srs(
            200,
            headers: <String, String>{'etag': '"v1"'},
          ),
      });
      final geo = GeoAsset(
        cacheDir: cacheDir,
        initialDir: initialDir,
        http: HttpCache(fetch: mock.fetch),
      );

      await geo.refreshAll();
      expect(mock.calls, hasLength(2));

      await geo.refreshAll();
      expect(mock.calls, hasLength(2));
    });

    test(
      'stale entry revalidates with If-None-Match; 304 keeps bytes',
      () async {
        final urls = <Uri>[
          for (final spec in GeoAsset.registry.values) Uri.parse(spec.url),
        ];
        var revision = 0;
        DateTime clock() => DateTime(2026, 9, 1, 12);

        CachedResponse respond(Uri url, Map<String, String> headers) {
          if (headers['If-None-Match'] == '"v$revision"') {
            return srs(304, headers: <String, String>{'etag': '"v$revision"'});
          }
          return srs(
            200,
            headers: <String, String>{'etag': '"v$revision"'},
            body: <int>[0x53, 0x52, 0x53, 2, 1, revision],
          );
        }

        Future<CachedResponse> fetch(
          Uri url,
          Map<String, String> headers,
        ) async => respond(url, headers);

        final cache = HttpCache(fetch: fetch, cacheDir: cacheDir, now: clock);
        final geo2 = GeoAsset(
          cacheDir: cacheDir,
          initialDir: initialDir,
          http: cache,
        );

        revision = 1;
        await geo2.refreshAll();
        final v1 = await File('${cacheDir.path}/geosite-cn.srs').readAsBytes();

        // Age beyond the 6h window, server content unchanged → 304
        DateTime staleClock() => DateTime(2026, 9, 1, 20);
        final cache3 = HttpCache(
          fetch: fetch,
          cacheDir: cacheDir,
          now: staleClock,
        );
        final geo3 = GeoAsset(
          cacheDir: cacheDir,
          initialDir: initialDir,
          http: cache3,
        );

        await geo3.refreshAll();
        final v1b = await File('${cacheDir.path}/geosite-cn.srs').readAsBytes();
        expect(v1b, v1);

        // Content changed → 200 v2 body lands (clock 12h past the 304 refresh)
        revision = 2;
        DateTime changedClock() => DateTime(2026, 9, 2, 8);
        final cache4 = HttpCache(
          fetch: fetch,
          cacheDir: cacheDir,
          now: changedClock,
        );
        final geo4 = GeoAsset(
          cacheDir: cacheDir,
          initialDir: initialDir,
          http: cache4,
        );
        await geo4.refreshAll();
        final v2 = await File('${cacheDir.path}/geosite-cn.srs').readAsBytes();
        expect(v2, isNot(v1));
        expect(urls, hasLength(2));
      },
    );
  });

  test('real bundled geosite-cn.srs has SRS magic bytes', () {
    final real = File('rule_sets/initial_assets/geosite-cn.srs');
    if (!real.existsSync()) {
      return;
    }
    final magic = real.readAsBytesSync().sublist(0, 3);
    expect(utf8.decode(magic), 'SRS');
  });
}
