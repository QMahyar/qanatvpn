import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qanatvpn/modules/onboarding/split_store.dart';
import 'package:qanatvpn/modules/vpn/repositories/profile_config_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('qanatvpn-split');
  });

  tearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  group('SplitStore', () {
    test('save + read round-trips allowlist mode', () async {
      final scoped = SplitStore(baseDir: dir.path);

      await scoped.save(
        const SplitChoice(
          allowMode: true,
          packages: <String>{'org.telegram.messenger', 'com.whatsapp'},
        ),
      );

      final choice = scoped.read();
      expect(choice?.allowMode, isTrue);
      expect(choice?.packages, <String>{
        'org.telegram.messenger',
        'com.whatsapp',
      });
    });

    test('save + read round-trips bypass mode', () async {
      final scoped = SplitStore(baseDir: dir.path);

      await scoped.save(
        const SplitChoice(allowMode: false, packages: <String>{'com.game'}),
      );

      final choice = scoped.read();
      expect(choice?.allowMode, isFalse);
      expect(choice?.packages, <String>{'com.game'});
    });

    test('clear removes the choice', () async {
      final scoped = SplitStore(baseDir: dir.path);
      await scoped.save(
        const SplitChoice(allowMode: true, packages: <String>{'a'}),
      );

      await scoped.clear();

      expect(scoped.read(), isNull);
    });

    test('read on empty store → null, corrupt file → null', () async {
      final scoped = SplitStore(baseDir: dir.path);
      expect(scoped.read(), isNull);

      File('${dir.path}/split_choice.json').writeAsStringSync('{broken');
      expect(scoped.read(), isNull);
    });
  });

  group('ProfileConfigSource split merge', () {
    test('allowlist choice → includePackages set', () async {
      final scoped = SplitStore(baseDir: dir.path);
      await scoped.save(
        const SplitChoice(
          allowMode: true,
          packages: <String>{'com.a', 'com.b'},
        ),
      );
      final source = ProfileConfigSource(
        splitStore: scoped,
        assetPath: 'profiles/config.wg-awg.json',
      );

      final config = await source.resolve('HKG-02');

      expect(config.includePackages, <String>['com.a', 'com.b']);
      expect(config.excludePackages, isEmpty);
      expect(config.requiresTor, isFalse);
    });

    test('bypass choice → excludePackages set', () async {
      final scoped = SplitStore(baseDir: dir.path);
      await scoped.save(
        const SplitChoice(allowMode: false, packages: <String>{'com.game'}),
      );
      final source = ProfileConfigSource(splitStore: scoped);

      final config = await source.resolve('HKG-02');

      expect(config.includePackages, isEmpty);
      expect(config.excludePackages, <String>['com.game']);
    });

    test(
      'no store / no choice → both lists empty, TOR tag still detected',
      () async {
        final source = ProfileConfigSource();

        final plain = await source.resolve('HKG-02');
        final tor = await source.resolve('TOR-CHAIN');

        expect(plain.includePackages, isEmpty);
        expect(plain.excludePackages, isEmpty);
        expect(tor.requiresTor, isTrue);
      },
    );
  });
}
