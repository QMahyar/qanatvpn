import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/modules/onboarding/split_store.dart';
import 'package:yourvpn/modules/routing/policy_store.dart';
import 'package:yourvpn/modules/routing/rule_store.dart';
import 'package:yourvpn/modules/vpn/repositories/endpoint_store.dart';
import 'package:yourvpn/modules/vpn/repositories/ingestion/normalized_endpoint.dart';
import 'package:yourvpn/modules/vpn/repositories/profile_config_source.dart';

/// Config rebuild caching: identical inputs hit the merge cache, changed
/// inputs miss, caller mutation cannot pollute the cache, and concurrent
/// resolves share one base-profile load.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yourvpn-cfgcache');
  });

  tearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  Map<String, dynamic> baseProfile() => <String, dynamic>{
    'outbounds': <dynamic>[
      <String, dynamic>{
        'type': 'selector',
        'tag': 'PROXY',
        'outbounds': <String>['DIRECT'],
      },
      <String, dynamic>{'type': 'direct', 'tag': 'DIRECT'},
    ],
    'route': <String, dynamic>{'rules': <dynamic>[]},
  };

  ProfileConfigSource source({int? loadCount}) {
    var loads = 0;
    final s = ProfileConfigSource(
      endpointStore: EndpointStore(baseDir: dir.path),
      policyStore: PolicyStore(baseDir: dir.path),
      ruleStore: RuleStore(baseDir: dir.path),
      splitStore: SplitStore(baseDir: dir.path),
    );
    s.loadForTest = () async {
      loads++;
      if (loadCount != null) {
        loadCount = loads;
      }
      return baseProfile();
    };
    return s;
  }

  StoredEndpoint trojan(String tag) => StoredEndpoint(
    endpoint: TrojanEndpoint(tag: tag, address: 'a', port: 443, password: 'p'),
    label: tag,
  );

  test('same inputs twice → second resolve is a cache hit', () async {
    final s = source();
    await EndpointStore(
      baseDir: dir.path,
    ).save(<StoredEndpoint>[trojan('t-1')]);

    await s.resolve('PROXY');
    expect(s.cacheStats(), 'hits=0 misses=1');
    await s.resolve('PROXY');
    expect(s.cacheStats(), 'hits=1 misses=1');
  });

  test('changed endpoints → miss and new content', () async {
    final s = source();
    final store = EndpointStore(baseDir: dir.path);
    await store.save(<StoredEndpoint>[trojan('t-1')]);

    final first = await s.resolve('PROXY');
    await store.save(<StoredEndpoint>[trojan('t-1'), trojan('t-2')]);
    final second = await s.resolve('PROXY');

    expect(s.cacheStats(), 'hits=0 misses=2');
    List<dynamic> tagsOf(Map<String, dynamic> json) {
      final outbounds = json['outbounds'] as List<dynamic>;
      final selector = outbounds.whereType<Map<String, dynamic>>().firstWhere(
        (o) => o['type'] == 'selector',
      );
      return selector['outbounds'] as List<dynamic>;
    }

    expect(tagsOf(first.json), contains('t-1'));
    expect(tagsOf(second.json), containsAll(<String>['t-1', 't-2']));
  });

  test('caller mutating the returned map does not pollute the cache', () async {
    final s = source();
    await EndpointStore(
      baseDir: dir.path,
    ).save(<StoredEndpoint>[trojan('t-1')]);

    final first = await s.resolve('PROXY');
    (first.json['outbounds'] as List<dynamic>).clear();
    final second = await s.resolve('PROXY');

    final outbounds = second.json['outbounds'] as List<dynamic>;
    final selector = outbounds.whereType<Map<String, dynamic>>().firstWhere(
      (o) => o['type'] == 'selector',
    );
    expect(selector['outbounds'], contains('t-1'));
    expect(s.cacheStats(), 'hits=1 misses=1');
  });

  test('concurrent resolves share one base-profile load', () async {
    var loads = 0;
    final s = ProfileConfigSource(
      endpointStore: EndpointStore(baseDir: dir.path),
      policyStore: PolicyStore(baseDir: dir.path),
      ruleStore: RuleStore(baseDir: dir.path),
    );
    s.loadForTest = () async {
      loads++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return baseProfile();
    };

    await Future.wait(<Future<void>>[
      s.resolve('PROXY'),
      s.resolve('PROXY'),
      s.resolve('OTHER'),
    ]);

    expect(loads, 1);
  });

  test('different tags cache independently', () async {
    final s = source();
    await s.resolve('PROXY');
    await s.resolve('TOR-ENTRY');
    await s.resolve('PROXY');

    expect(s.cacheStats(), 'hits=1 misses=2');
  });
}
