import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/modules/routing/groups_controller.dart';
import 'package:yourvpn/modules/routing/policy_store.dart';
import 'package:yourvpn/modules/routing/routing_policy.dart';
import 'package:yourvpn/modules/vpn/logic/selected_endpoint.dart';
import 'package:yourvpn/modules/vpn/repositories/endpoints_controller.dart'
    show endpointStoreProvider;
import 'package:yourvpn/modules/vpn/repositories/endpoint_store.dart';
import 'package:yourvpn/modules/vpn/repositories/ingestion/normalized_endpoint.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yourvpn-selected');
  });

  tearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  StoredEndpoint trojan(String tag) => StoredEndpoint(
    endpoint: TrojanEndpoint(tag: tag, address: 'a', port: 443, password: 'p'),
    label: tag,
  );

  test('group default member wins over stored endpoints', () async {
    final policyStore = PolicyStore(baseDir: dir.path);
    await policyStore.save(
      const PolicyDocument(
        groups: <OutboundGroup>[
          OutboundGroup.selector(
            tag: 'manual',
            members: <String>['DIRECT', 'trojan-1'],
            defaultMember: 'trojan-1',
          ),
        ],
        leafOutbounds: <String>['trojan-1'],
      ),
    );
    final endpointStore = EndpointStore(baseDir: dir.path);
    await endpointStore.save(<StoredEndpoint>[trojan('trojan-1')]);

    final container = ProviderContainer(
      overrides: [
        policyStoreProvider.overrideWithValue(policyStore),
        endpointStoreProvider.overrideWithValue(endpointStore),
      ],
    );
    addTearDown(container.dispose);

    final selected = container.read(selectedEndpointProvider);

    expect(selected.tag, 'trojan-1');
    expect(selected.source, 'group');
  });

  test('first stored endpoint when no groups', () async {
    final endpointStore = EndpointStore(baseDir: dir.path);
    await endpointStore.save(<StoredEndpoint>[
      trojan('trojan-1'),
      trojan('trojan-2'),
    ]);

    final container = ProviderContainer(
      overrides: [endpointStoreProvider.overrideWithValue(endpointStore)],
    );
    addTearDown(container.dispose);

    final selected = container.read(selectedEndpointProvider);

    expect(selected.tag, 'trojan-1');
    expect(selected.source, 'endpoint');
  });

  test('falls back to vendored profile tag with nothing stored', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final selected = container.read(selectedEndpointProvider);

    expect(selected.tag, 'awg-hkg-02');
    expect(selected.source, 'fallback');
    expect(selected.hadDeadTag, isFalse);
  });

  test('dead group member falls back with deadTag warning', () async {
    final policyStore = PolicyStore(baseDir: dir.path);
    await policyStore.save(
      const PolicyDocument(
        groups: <OutboundGroup>[
          OutboundGroup.selector(
            tag: 'manual',
            members: <String>['ghost-tag'],
            defaultMember: 'ghost-tag',
          ),
        ],
        leafOutbounds: <String>[],
      ),
    );
    final endpointStore = EndpointStore(baseDir: dir.path);
    await endpointStore.save(<StoredEndpoint>[trojan('trojan-1')]);

    final container = ProviderContainer(
      overrides: [
        policyStoreProvider.overrideWithValue(policyStore),
        endpointStoreProvider.overrideWithValue(endpointStore),
      ],
    );
    addTearDown(container.dispose);

    final selected = container.read(selectedEndpointProvider);

    expect(selected.tag, 'trojan-1');
    expect(selected.source, 'endpoint');
    expect(selected.deadTag, 'ghost-tag');
    expect(selected.hadDeadTag, isTrue);
  });

  test('dead group member with nothing else falls back to vendored tag',
      () async {
    final policyStore = PolicyStore(baseDir: dir.path);
    await policyStore.save(
      const PolicyDocument(
        groups: <OutboundGroup>[
          OutboundGroup.selector(
            tag: 'manual',
            members: <String>['ghost-tag'],
          ),
        ],
        leafOutbounds: <String>[],
      ),
    );

    final container = ProviderContainer(
      overrides: [policyStoreProvider.overrideWithValue(policyStore)],
    );
    addTearDown(container.dispose);

    final selected = container.read(selectedEndpointProvider);

    expect(selected.tag, 'awg-hkg-02');
    expect(selected.source, 'fallback');
    expect(selected.deadTag, 'ghost-tag');
  });
}
