import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qanatvpn/modules/routing/groups_controller.dart';
import 'package:qanatvpn/modules/routing/policy_store.dart';
import 'package:qanatvpn/modules/routing/routing_policy.dart';
import 'package:qanatvpn/modules/routing/rule_store.dart';
import 'package:qanatvpn/modules/routing/rules_controller.dart';
import 'package:qanatvpn/modules/vpn/repositories/endpoint_store.dart';
import 'package:qanatvpn/modules/vpn/repositories/endpoints_controller.dart';
import 'package:qanatvpn/modules/vpn/repositories/ingestion/normalized_endpoint.dart';

/// Store write coalescing: rapid controller edits update state immediately
/// but hit disk once (debounced). A kill mid-burst loses nothing already
/// visible — the next edit re-saves the full list.
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('qanatvpn-coalesce');
  });

  tearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  RouteRule rule(String domain) =>
      RouteRule(outbound: 'DIRECT', domains: <String>[domain]);

  test('RulesController: 3 rapid addRule → 1 disk write with all 3', () async {
    final container = ProviderContainer(
      overrides: [
        ruleStoreProvider.overrideWithValue(RuleStore(baseDir: dir.path)),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(rulesControllerProvider.notifier);

    await controller.addRule(rule('a.com'));
    await controller.addRule(rule('b.com'));
    await controller.addRule(rule('c.com'));

    // State is immediate even before the disk write lands.
    expect(container.read(rulesControllerProvider).rules, hasLength(3));
    expect(File('${dir.path}/rules.json').existsSync(), isFalse);

    await controller.flushPending();

    final raw = File('${dir.path}/rules.json').readAsStringSync();
    final doc = jsonDecode(raw) as Map<String, dynamic>;
    expect((doc['rules'] as List<dynamic>), hasLength(3));
    // No tmp leftovers from the atomic write.
    expect(dir.listSync().where((e) => e.path.endsWith('.tmp')), isEmpty);
  });

  test('GroupsController: rapid edits coalesce, state stays ahead', () async {
    final container = ProviderContainer(
      overrides: [
        policyStoreProvider.overrideWithValue(PolicyStore(baseDir: dir.path)),
        endpointStoreProvider.overrideWithValue(
          EndpointStore(baseDir: dir.path),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(groupsControllerProvider.notifier);

    await controller.addGroup(
      const OutboundGroup.selector(tag: 'a', members: <String>['DIRECT']),
    );
    await controller.addGroup(
      const OutboundGroup.selector(tag: 'b', members: <String>['DIRECT']),
    );
    expect(container.read(groupsControllerProvider).groups, hasLength(2));
    expect(File('${dir.path}/policy.json').existsSync(), isFalse);

    await controller.flushPending();
    expect(container.read(policyStoreProvider).read().groups, hasLength(2));
  });

  test(
    'EndpointsController: saveManual is immediate, disk debounced',
    () async {
      final container = ProviderContainer(
        overrides: [
          endpointStoreProvider.overrideWithValue(
            EndpointStore(baseDir: dir.path),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(endpointsControllerProvider.notifier);

      const endpoint = TrojanEndpoint(
        tag: 't-1',
        address: 'a',
        port: 443,
        password: 'p',
      );
      const stored = StoredEndpoint(endpoint: endpoint, label: 't-1');
      await EndpointStore(baseDir: dir.path).save(<StoredEndpoint>[stored]);
      await controller.delete(0);

      expect(container.read(endpointsControllerProvider).endpoints, isEmpty);
      await controller.flushPending();
      expect(EndpointStore(baseDir: dir.path).read(), isEmpty);
    },
  );
}
