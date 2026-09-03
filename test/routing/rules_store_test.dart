import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/modules/routing/rule_store.dart';
import 'package:yourvpn/modules/routing/routing_policy.dart';
import 'package:yourvpn/modules/vpn/repositories/profile_config_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yourvpn-rules');
  });

  tearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  group('RuleStore', () {
    test('round-trips typed rules', () async {
      final store = RuleStore(baseDir: dir.path);
      const doc = RuleDocument(
        rules: <RouteRule>[
          RouteRule(
            outbound: 'BLOCK',
            processNames: <String>['steam.exe'],
            invert: true,
          ),
          RouteRule(
            outbound: 'DIRECT',
            domainSuffixes: <String>['cn'],
            ports: <String>['443'],
          ),
        ],
      );

      await store.save(doc);
      final read = store.read();

      expect(read.rules, hasLength(2));
      expect(read.rules[0].outbound, 'BLOCK');
      expect(read.rules[0].processNames, <String>['steam.exe']);
      expect(read.rules[0].invert, isTrue);
      expect(read.rules[1].domainSuffixes, <String>['cn']);
      expect(read.rules[1].ports, <String>['443']);
    });

    test('corrupt store → empty document', () {
      final store = RuleStore(baseDir: dir.path);
      File('${dir.path}/rules.json').writeAsStringSync('{{{');

      expect(store.read().rules, isEmpty);
    });
  });

  group('ProfileConfigSource rules merge', () {
    test(
      'valid rules append after profile rules (firewall-first preserved)',
      () async {
        final ruleStore = RuleStore(baseDir: dir.path);
        await ruleStore.save(
          const RuleDocument(
            rules: <RouteRule>[
              RouteRule(outbound: 'BLOCK', processNames: <String>['steam.exe']),
            ],
          ),
        );
        final source = ProfileConfigSource(ruleStore: ruleStore);

        final config = await source.resolve('HKG-02');

        final rules =
            (config.json['route'] as Map<String, dynamic>)['rules']
                as List<dynamic>;
        // Profile rules first (hijack-dns + others), user rule last.
        expect((rules.first as Map<String, dynamic>)['action'], 'hijack-dns');
        final last = rules.last as Map<String, dynamic>;
        expect(last['process_name'], <String>['steam.exe']);
        expect(last['action'], 'reject');
      },
    );

    test('invalid rule set → profile ships unmodified', () async {
      final ruleStore = RuleStore(baseDir: dir.path);
      await ruleStore.save(
        const RuleDocument(
          rules: <RouteRule>[RouteRule(outbound: 'BLOCK')], // no conditions
        ),
      );
      final source = ProfileConfigSource(ruleStore: ruleStore);

      final config = await source.resolve('HKG-02');

      final rules =
          (config.json['route'] as Map<String, dynamic>)['rules']
              as List<dynamic>;
      expect(rules, hasLength(3)); // profile's own rules only
    });
  });
}
