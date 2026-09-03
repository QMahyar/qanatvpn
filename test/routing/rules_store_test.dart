import 'dart:convert';
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

  group('RuleStore v2 full-field round-trip (P0)', () {
    test('all 30 fields + nested logical rules survive save/load', () async {
      final dir = await Directory.systemTemp.createTemp('rules_v2');
      addTearDown(() => dir.deleteSync(recursive: true));
      const store = RuleStore();
      final doc = const RuleDocument(
        rules: <RouteRule>[
          RouteRule(
            outbound: 'PROXY',
            domains: <String>['example.com'],
            domainSuffixes: <String>['example.org'],
            domainKeywords: <String>['cdn'],
            domainRegex: <String>['^api.'],
            geosite: <String>['cn'],
            geoip: <String>['cn'],
            ipCidrs: <String>['10.0.0.0/8'],
            sourceIpCidrs: <String>['192.168.1.0/24'],
            ports: <String>['443'],
            sourcePorts: <String>['1024'],
            portRanges: <String>['1000:2000'],
            sourcePortRanges: <String>['3000:4000'],
            networks: <String>['tcp'],
            protocols: <String>['tls'],
            ipVersion: 4,
            ipIsPrivate: true,
            sourceIpIsPrivate: false,
            packageNames: <String>['com.example'],
            processNames: <String>['chrome.exe'],
            processPaths: <String>['C:/a/b.exe'],
            processPathRegexes: <String>['.*chrome.*'],
            userIds: <int>[1000],
            wifiSsids: <String>['home'],
            wifiBssids: <String>['aa:bb'],
            users: <String>['u'],
            inbounds: <String>['tun-in'],
            ruleSets: <String>['geosite-cn'],
            clashMode: 'Direct',
            logicalMode: 'and',
            rules: <RouteRule>[
              RouteRule(
                domains: <String>['a.com'],
                ports: <String>['80'],
              ),
              RouteRule(
                domains: <String>['b.com'],
                ports: <String>['443'],
              ),
            ],
            invert: true,
          ),
        ],
      );
      // ignore: invalid_use_of_visible_for_testing_member
      await RuleStore(baseDir: dir.path).save(doc);
      final loaded = RuleStore(baseDir: dir.path).read();
      expect(loaded.rules, hasLength(1));
      final roundTripped = RuleDocument(rules: loaded.rules).toJson();
      final reread = RuleDocument.fromJson(
        jsonDecode(jsonEncode(roundTripped)) as Map<String, dynamic>,
      );
      final rule = reread.rules.single;
      expect(rule.domainRegex, <String>['^api.']);
      expect(rule.geosite, <String>['cn']);
      expect(rule.sourceIpCidrs, <String>['192.168.1.0/24']);
      expect(rule.sourcePorts, <String>['1024']);
      expect(rule.sourcePortRanges, <String>['3000:4000']);
      expect(rule.protocols, <String>['tls']);
      expect(rule.ipVersion, 4);
      expect(rule.packageNames, <String>['com.example']);
      expect(rule.processPaths, <String>['C:/a/b.exe']);
      expect(rule.userIds, <int>[1000]);
      expect(rule.wifiSsids, <String>['home']);
      expect(rule.rules, hasLength(2));
      expect(store, isNotNull);
    });
  });
}
