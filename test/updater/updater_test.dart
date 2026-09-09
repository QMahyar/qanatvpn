import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:qanatvpn/core/network/http_cache.dart';
import 'package:qanatvpn/modules/updates/updater.dart';

CachedResponse response(
  int statusCode, {
  Map<String, String> headers = const <String, String>{},
  Map<String, dynamic>? body,
}) {
  return CachedResponse(
    statusCode: statusCode,
    headers: headers,
    body: Uint8List.fromList(utf8.encode(body == null ? '' : jsonEncode(body))),
  );
}

Map<String, dynamic> releaseDoc({List<Map<String, dynamic>>? assets}) =>
    <String, dynamic>{
      'tag_name': 'v1.2.3',
      'body': 'Bug fixes',
      'assets':
          assets ??
          <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'qanatvpn_v1.2.3_arm64-v8a.apk',
              'browser_download_url': 'https://github.com/x/arm64.apk',
            },
            <String, dynamic>{
              'name': 'qanatvpn_v1.2.3_windows-x64.zip',
              'browser_download_url': 'https://github.com/x/win.zip',
            },
          ],
    };

void main() {
  group('UpdateFetcher', () {
    test('403 + x-ratelimit-remaining:0 → GitHubRateLimitException', () async {
      final fetcher = UpdateFetcher(
        fetchImpl: (Uri url, Map<String, String> headers) async => response(
          403,
          headers: <String, String>{
            'x-ratelimit-remaining': '0',
            'x-ratelimit-reset': '1750000000',
          },
        ),
      );

      await expectLater(
        fetcher.latestFor('android-arm64'),
        throwsA(isA<GitHubRateLimitException>()),
      );
    });

    test('429 → RateLimitException with retryAfter', () async {
      final fetcher = UpdateFetcher(
        fetchImpl: (Uri url, Map<String, String> headers) async =>
            response(429, headers: <String, String>{'retry-after': '90'}),
      );

      try {
        await fetcher.latestFor('android-arm64');
        fail('expected RateLimitException');
      } on RateLimitException catch (e) {
        expect(e.retryAfter, const Duration(seconds: 90));
      }
    });

    test(
      '401 surfaces a distinct error (retry unauthenticated path)',
      () async {
        final fetcher = UpdateFetcher(
          fetchImpl: (Uri url, Map<String, String> headers) async =>
              response(401),
        );

        await expectLater(
          fetcher.latestFor('android-arm64'),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('happy path picks the platform asset', () async {
      final fetcher = UpdateFetcher(
        fetchImpl: (Uri url, Map<String, String> headers) async =>
            response(200, body: releaseDoc()),
      );

      final info = await fetcher.latestFor('windows-x64');
      expect(info.version, 'v1.2.3');
      expect(info.assetUrl, 'https://github.com/x/win.zip');
      expect(info.changelog, 'Bug fixes');
    });

    test('no matching asset → clear error', () async {
      final fetcher = UpdateFetcher(
        fetchImpl: (Uri url, Map<String, String> headers) async => response(
          200,
          body: releaseDoc(
            assets: <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'other.txt',
                'browser_download_url': 'https://github.com/x/other.txt',
              },
            ],
          ),
        ),
      );

      await expectLater(
        fetcher.latestFor('android-arm64'),
        throwsA(isA<FormatException>()),
      );
    });

    test('unknown platform key → ArgumentError', () {
      final fetcher = UpdateFetcher(
        fetchImpl: (Uri url, Map<String, String> headers) async =>
            response(200),
      );

      expect(() => fetcher.latestFor('ios-arm64'), throwsArgumentError);
    });
  });

  group('UpdateInfo.semver', () {
    test('isNewerThan compares numerically', () {
      const info = UpdateInfo(
        version: 'v1.10.0',
        changelog: '',
        assetUrl: '',
        platformKey: 'windows-x64',
      );

      expect(info.isNewerThan('1.9.9'), isTrue);
      expect(info.isNewerThan('1.10.0'), isFalse);
      expect(info.isNewerThan('2.0.0'), isFalse);
    });
  });

  group('latestJson', () {
    test('platform map mirrors release assets', () {
      final fetcher = UpdateFetcher(
        fetchImpl: (Uri url, Map<String, String> headers) async =>
            response(200),
      );
      final json = fetcher.latestJsonFromRelease(releaseDoc());

      final platforms = json['platforms'] as Map<String, dynamic>;
      expect(
        (platforms['android-arm64'] as Map<String, dynamic>)['url'],
        'https://github.com/x/arm64.apk',
      );
      expect(
        (platforms['windows-x64'] as Map<String, dynamic>)['url'],
        'https://github.com/x/win.zip',
      );
      expect(json['version'], 'v1.2.3');
    });
  });

  group('UpdateSource (api → mirror fallback)', () {
    test('api success wins, mirror untouched', () async {
      final urls = <Uri>[];
      final source = UpdateSource(
        fetchImpl: (Uri url, Map<String, String> headers) async {
          urls.add(url);
          return response(200, body: releaseDoc());
        },
        mirrorUrl: 'https://example.github.io/qanatvpn/latest.json',
      );

      final info = await source.latestFor('android-arm64');

      expect(info?.version, 'v1.2.3');
      expect(urls, hasLength(1));
      expect(urls.single.host, 'api.github.com');
    });

    test('api rate-limited → mirror serves platform entry', () async {
      final source = UpdateSource(
        fetchImpl: (Uri url, Map<String, String> headers) async {
          if (url.host == 'api.github.com') {
            return response(
              403,
              headers: <String, String>{'x-ratelimit-remaining': '0'},
            );
          }
          return response(
            200,
            body: <String, dynamic>{
              'version': 'v1.2.3',
              'platforms': <String, dynamic>{
                'android-arm64': <String, dynamic>{
                  'url': 'https://github.com/x/arm64.apk',
                  'version': 'v1.2.3',
                },
              },
            },
          );
        },
        mirrorUrl: 'https://example.github.io/qanatvpn/latest.json',
      );

      final info = await source.latestFor('android-arm64');

      expect(info?.assetUrl, 'https://github.com/x/arm64.apk');
      expect(info?.changelog, isEmpty);
    });

    test('api failed + no mirror → original api error surfaces', () async {
      final source = UpdateSource(
        fetchImpl: (Uri url, Map<String, String> headers) async => response(
          403,
          headers: <String, String>{'x-ratelimit-remaining': '0'},
        ),
      );

      await expectLater(
        source.latestFor('android-arm64'),
        throwsA(isA<GitHubRateLimitException>()),
      );
    });

    test('mirror 404 → api error surfaces', () async {
      final source = UpdateSource(
        fetchImpl: (Uri url, Map<String, String> headers) async {
          if (url.host == 'api.github.com') {
            return response(500);
          }
          return response(404);
        },
        mirrorUrl: 'https://example.github.io/qanatvpn/latest.json',
      );

      await expectLater(
        source.latestFor('android-arm64'),
        throwsA(isA<HttpException>()),
      );
    });
  });

  group('UpdateStore', () {
    test('save + read round-trips the update info', () async {
      final dir = await Directory.systemTemp.createTemp('qanatvpn-store');
      addTearDown(() => dir.delete(recursive: true));
      final store = UpdateStore(baseDir: dir.path);
      const info = UpdateInfo(
        version: 'v1.2.3',
        changelog: 'Bug fixes',
        assetUrl: 'https://github.com/x/arm64.apk',
        platformKey: 'android-arm64',
      );

      await store.save(info, '1.0.0');

      final read = store.read();
      expect(read?.version, 'v1.2.3');
      expect(read?.assetUrl, 'https://github.com/x/arm64.apk');
      expect(store.lastCheckedAt(), isNotNull);
    });

    test('read on empty store → null, never throws', () {
      final store = UpdateStore(
        baseDir: Directory.systemTemp
            .createTempSync('qanatvpn-store-empty')
            .path,
      );

      expect(store.read(), isNull);
      expect(store.lastCheckedAt(), isNull);
    });
  });
}
