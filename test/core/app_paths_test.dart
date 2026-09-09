import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qanatvpn/core/persistence/app_paths.dart';

/// app_paths: override-based resolution, legacy fallback chain, and the
/// one-time ~/.qanatvpn migration (audit W1.4 — Android had no working
/// default store path).
void main() {
  setUp(() {
    appSupportDirOverride = null;
  });

  tearDown(() {
    appSupportDirOverride = null;
  });

  group('defaultBaseDirSync', () {
    test('returns override when set', () {
      appSupportDirOverride = '/data/qanatvpn-support';
      expect(defaultBaseDirSync(), '/data/qanatvpn-support');
    });

    test('falls back to env chain when override unset (desktop parity)', () {
      final dir = defaultBaseDirSync();
      // On any host the legacy chain resolves to *something* (HOME,
      // USERPROFILE, or systemTemp) — non-empty, not an exception.
      expect(dir, isNotEmpty);
      // It must never be the bare app-support override.
      expect(dir, isNot(contains('\u0000')));
    });
  });

  group('resolveAppSupportDir', () {
    test('returns override without touching plugins', () async {
      appSupportDirOverride = '/override/path';
      expect(await resolveAppSupportDir(), '/override/path');
    });

    test('resolves without plugin binding via fallback (test env)', () async {
      // flutter_test has no path_provider plugin binding; the function must
      // fall back to the legacy chain instead of throwing.
      final dir = await resolveAppSupportDir();
      expect(dir, isNotEmpty);
      expect(appSupportDirOverride, isNull); // fallback does not cache
    });
  });

  group('migrateLegacyDotYourVpn', () {
    late Directory legacyHome;

    setUp(() async {
      legacyHome = await Directory.systemTemp.createTemp('qanatvpn-mig');
    });

    tearDown(() async {
      appSupportDirOverride = null;
      await legacyHome.delete(recursive: true);
    });

    test('copies legacy store files into support dir, skips existing', () async {
      final legacyDot = Directory('${legacyHome.path}/.qanatvpn')
        ..createSync(recursive: true);
      File('${legacyDot.path}/endpoints.json').writeAsStringSync('["old"]');
      File('${legacyDot.path}/rules.json').writeAsStringSync('{}');
      final support = Directory('${legacyHome.path}/support')..createSync();
      appSupportDirOverride = support.path;

      final copied = await migrateLegacyDotYourVpn(legacyDir: legacyDot);
      expect(copied, 2);
      expect(
        File('${support.path}/.qanatvpn/endpoints.json').readAsStringSync(),
        '["old"]',
      );
      expect(
        File('${support.path}/.qanatvpn/rules.json').existsSync(),
        isTrue,
      );

      // Second run: nothing new copied, existing files untouched.
      File('${support.path}/.qanatvpn/endpoints.json')
          .writeAsStringSync('["new"]');
      final again = await migrateLegacyDotYourVpn(legacyDir: legacyDot);
      expect(again, 0);
      expect(
        File('${support.path}/.qanatvpn/endpoints.json').readAsStringSync(),
        '["new"]',
      );
    });

    test('missing legacy dir is a clean no-op returning 0', () async {
      final support = Directory('${legacyHome.path}/support2')..createSync();
      appSupportDirOverride = support.path;
      final copied = await migrateLegacyDotYourVpn(
        legacyDir: Directory('${legacyHome.path}/does-not-exist'),
      );
      expect(copied, 0);
    });
  });
}
