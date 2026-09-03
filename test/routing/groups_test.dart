import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/modules/routing/groups_controller.dart';
import 'package:yourvpn/modules/routing/policy_store.dart';
import 'package:yourvpn/modules/routing/routing_policy.dart';
import 'package:yourvpn/modules/vpn/repositories/profile_config_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yourvpn-policy');
  });

  tearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  group('PolicyStore', () {
    test('round-trips selector and urltest groups', () async {
      final store = PolicyStore(baseDir: dir.path);
      const doc = PolicyDocument(
        groups: <OutboundGroup>[
          OutboundGroup.urlTest(tag: 'auto', members: <String>['awg-1']),
          OutboundGroup.selector(
            tag: 'manual',
            members: <String>['auto', 'DIRECT'],
            defaultMember: 'auto',
            interruptExistConnections: true,
          ),
        ],
        leafOutbounds: <String>['awg-1'],
      );

      await store.save(doc);
      final read = store.read();

      expect(read.leafOutbounds, <String>['awg-1']);
      expect(read.groups, hasLength(2));
      final auto = read.groups[0];
      expect(auto.isUrlTest, isTrue);
      expect(auto.tag, 'auto');
      expect(auto.interval, const Duration(minutes: 5));
      final manual = read.groups[1];
      expect(manual.isUrlTest, isFalse);
      expect(manual.defaultMember, 'auto');
      expect(manual.interruptExistConnections, isTrue);
    });

    test('corrupt file → empty document, never throws', () {
      final store = PolicyStore(baseDir: dir.path);
      File('${dir.path}/policy.json').writeAsStringSync('{nope');

      final doc = store.read();

      expect(doc.groups, isEmpty);
      expect(doc.leafOutbounds, isEmpty);
    });
  });

  group('ProfileConfigSource group injection', () {
    test(
      'valid groups injected ahead of selector; selector gains tags',
      () async {
        final store = PolicyStore(baseDir: dir.path);
        await store.save(
          const PolicyDocument(
            groups: <OutboundGroup>[
              OutboundGroup.urlTest(
                tag: 'auto',
                members: <String>['awg-hkg-02'],
              ),
            ],
            leafOutbounds: <String>['awg-hkg-02'],
          ),
        );
        final source = ProfileConfigSource(policyStore: store);

        final config = await source.resolve('HKG-02');

        final outbounds = config.json['outbounds'] as List<dynamic>;
        final tags = outbounds
            .map((o) => (o as Map<String, dynamic>)['tag'])
            .toList();
        // Injected group precedes the envelope; PROXY selector includes it.
        expect(tags.first, 'auto');
        final selector = outbounds.whereType<Map<String, dynamic>>().firstWhere(
          (o) => o['tag'] == 'PROXY',
        );
        expect((selector['outbounds'] as List<dynamic>), contains('auto'));
        // Re-resolve patches fresh from the cached base (never mutates it).
        final second = await source.resolve('HKG-02');
        expect(second.json['outbounds'], equals(config.json['outbounds']));
        expect(identical(second.json, config.json), isFalse);
      },
    );

    test(
      'broken policy (unknown member) ships the unmodified profile',
      () async {
        final store = PolicyStore(baseDir: dir.path);
        await store.save(
          const PolicyDocument(
            groups: <OutboundGroup>[
              OutboundGroup.urlTest(tag: 'auto', members: <String>['ghost']),
            ],
            leafOutbounds: <String>[],
          ),
        );
        final source = ProfileConfigSource(policyStore: store);

        final config = await source.resolve('HKG-02');

        final outbounds = config.json['outbounds'] as List<dynamic>;
        expect(
          outbounds.where((o) => (o as Map<String, dynamic>)['tag'] == 'auto'),
          isEmpty,
        );
      },
    );

    test('no policy store → profile shape unchanged', () async {
      final source = ProfileConfigSource();

      final config = await source.resolve('HKG-02');

      final outbounds = config.json['outbounds'] as List<dynamic>;
      expect(outbounds, hasLength(2)); // PROXY + DIRECT only
    });
  });

  group('GroupsController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          policyStoreProvider.overrideWithValue(PolicyStore(baseDir: dir.path)),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('addGroup persists and validates; bad member surfaces', () async {
      final controller = container.read(groupsControllerProvider.notifier);

      await controller.addGroup(
        const OutboundGroup.urlTest(tag: 'auto', members: <String>['DIRECT']),
      );
      expect(container.read(groupsControllerProvider).groups, hasLength(1));
      expect(
        container.read(groupsControllerProvider).isValid,
        isTrue,
        reason: container
            .read(groupsControllerProvider)
            .validationErrors
            .join(),
      );

      await controller.addGroup(
        const OutboundGroup.selector(tag: 'broken', members: <String>['ghost']),
      );
      final state = container.read(groupsControllerProvider);
      expect(state.groups, hasLength(2));
      expect(state.isValid, isFalse);
      expect(state.validationErrors, contains(contains('ghost')));

      // Broken group persisted too — the editor shows it; connect ignores it.
      expect(container.read(policyStoreProvider).read().groups, hasLength(2));
    });

    test('deleteGroup removes and persists', () async {
      final controller = container.read(groupsControllerProvider.notifier);
      await controller.addGroup(
        const OutboundGroup.selector(tag: 'a', members: <String>['DIRECT']),
      );
      await controller.addGroup(
        const OutboundGroup.selector(tag: 'b', members: <String>['DIRECT']),
      );

      await controller.deleteGroup(0);

      final state = container.read(groupsControllerProvider);
      expect(state.groups.single.tag, 'b');
      expect(container.read(policyStoreProvider).read().groups.single.tag, 'b');
    });
  });
}
