import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/core/network/http_cache.dart';
import 'package:yourvpn/modules/updates/updater.dart';

CachedResponse response(
  int statusCode, {
  Map<String, String> headers = const <String, String>{},
  Map<String, dynamic>? body,
}) {
  return CachedResponse(
    statusCode: statusCode,
    headers: headers,
    body: Uint8List.fromList(
      utf8.encode(body == null ? '' : jsonEncode(body)),
    ),
  );
}

Map<String, dynamic> releaseDoc({List<Map<String, dynamic>>? assets}) =>
    <String, dynamic>{
      'tag_name': 'v1.2.3',
      'body': 'Bug fixes',
      'assets': assets ??
          <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'yourvpn_v1.2.3_arm64-v8a.apk',
              'browser_download_url': 'https://github.com/x/arm64.apk',
            },
            <String, dynamic>{
              'name': 'yourvpn_v1.2.3_windows-x64.zip',
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

    test('401 surfaces a distinct error (retry unauthenticated path)', () async {
      final fetcher = UpdateFetcher(
        fetchImpl: (Uri url, Map<String, String> headers) async => response(401),
      );

      await expectLater(
        fetcher.latestFor('android-arm64'),
        throwsA(isA<FormatException>()),
      );
    });

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
        fetchImpl: (Uri url, Map<String, String> headers) async => response(200),
      );

      expect(
        () => fetcher.latestFor('ios-arm64'),
        throwsArgumentError,
      );
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
        fetchImpl: (Uri url, Map<String, String> headers) async => response(200),
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
}

