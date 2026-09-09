import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qanatvpn/core/network/http_cache.dart';
import 'package:qanatvpn/modules/updates/updates_controller.dart';
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

Map<String, dynamic> releaseDoc() => <String, dynamic>{
  'tag_name': 'v1.2.3',
  'body': 'Bug fixes',
  'assets': <Map<String, dynamic>>[
    <String, dynamic>{
      'name': 'qanatvpn_v1.2.3_arm64-v8a.apk',
      'browser_download_url': 'https://github.com/x/arm64.apk',
    },
  ],
};

ProviderContainer containerWith({
  required Directory dir,
  required Fetch fetch,
  String platformKey = 'android-arm64',
}) {
  return ProviderContainer(
    overrides: [
      updateStoreProvider.overrideWithValue(UpdateStore(baseDir: dir.path)),
      updateFetchProvider.overrideWithValue(fetch),
      updatePlatformKeyProvider.overrideWithValue(platformKey),
    ],
  );
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('qanatvpn-update-ctrl');
  });

  tearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  test('stored update renders Available at startup without network', () async {
    await UpdateStore(baseDir: dir.path).save(
      const UpdateInfo(
        version: 'v1.2.3',
        changelog: 'x',
        assetUrl: 'https://github.com/x/arm64.apk',
        platformKey: 'android-arm64',
      ),
      '1.0.0',
    );
    // Fresh container on the same dir (simulates restart): no network.
    final restart = containerWith(
      dir: dir,
      fetch: (_, _) async => throw const SocketException('offline'),
    );
    addTearDown(restart.dispose);

    final state = restart.read(updateControllerProvider);
    expect(state, isA<UpdateAvailable>());
  });

  test('checkNow success → Available + persisted', () async {
    final container = containerWith(
      dir: dir,
      fetch: (url, headers) async => response(200, body: releaseDoc()),
    );
    addTearDown(container.dispose);
    final controller = container.read(updateControllerProvider.notifier);

    await controller.checkNow(localVersion: '1.0.0');

    final state = container.read(updateControllerProvider);
    expect(state, isA<UpdateAvailable>());
    expect(
      (state as UpdateAvailable).info.assetUrl,
      'https://github.com/x/arm64.apk',
    );
    expect(container.read(updateStoreProvider).read()?.version, 'v1.2.3');
  });

  test('checkNow same version → UpToDate', () async {
    final container = containerWith(
      dir: dir,
      fetch: (url, headers) async => response(200, body: releaseDoc()),
    );
    addTearDown(container.dispose);

    await container
        .read(updateControllerProvider.notifier)
        .checkNow(localVersion: 'v1.2.3');

    expect(container.read(updateControllerProvider), isA<UpdateUpToDate>());
  });

  test('checkNow rate-limited → Failed (not a crash)', () async {
    final container = containerWith(
      dir: dir,
      fetch: (url, headers) async => response(
        403,
        headers: <String, String>{'x-ratelimit-remaining': '0'},
      ),
    );
    addTearDown(container.dispose);

    await container
        .read(updateControllerProvider.notifier)
        .checkNow(localVersion: '1.0.0');

    final state = container.read(updateControllerProvider);
    expect(state, isA<UpdateFailed>());
    expect((state as UpdateFailed).message, isNotEmpty);
  });

  test(
    'checkNow offline with empty store → Failed, store stays empty',
    () async {
      final container = containerWith(
        dir: dir,
        fetch: (_, _) async => throw const SocketException('offline'),
      );
      addTearDown(container.dispose);

      await container
          .read(updateControllerProvider.notifier)
          .checkNow(localVersion: '1.0.0');

      expect(container.read(updateControllerProvider), isA<UpdateFailed>());
      expect(container.read(updateStoreProvider).read(), isNull);
    },
  );
}
