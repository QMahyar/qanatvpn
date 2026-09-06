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
import 'package:yourvpn/modules/vpn/repositories/selection_store.dart';

/// Audit W2.1: the user can choose which server to connect to — a
/// persisted, tap-driven selection that survives restarts and falls back
/// with a visible warning when the pick dies.
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yourvpn-selection');
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

  ProviderContainer containerWith({
    EndpointStore? endpointStore,
    PolicyStore? policyStore,
  }) {
    final container = ProviderContainer(
      overrides: [
        selectionStoreProvider.overrideWithValue(
          SelectionStore(baseDir: dir.path),
        ),
        if (endpointStore != null)
          endpointStoreProvider.overrideWithValue(endpointStore),
        if (policyStore != null)
          policyStoreProvider.overrideWithValue(policyStore),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('user selection persists and wins over group default', () async {
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
    await endpointStore.save(<StoredEndpoint>[
      trojan('trojan-1'),
      trojan('trojan-2'),
    ]);

    final container = containerWith(
      endpointStore: endpointStore,
      policyStore: policyStore,
    );

    // Without a pick: group default wins.
    expect(container.read(selectedEndpointProvider).source, 'group');
    expect(container.read(selectedEndpointProvider).tag, 'trojan-1');

    // User picks trojan-2: user source wins over group default.
    await container
        .read(selectedEndpointProvider.notifier)
        .select('trojan-2');
    final picked = container.read(selectedEndpointProvider);
    expect(picked.tag, 'trojan-2');
    expect(picked.source, 'user');

    // The pick survives a fresh container (app restart) because it is
    // persisted in the store, not just notifier state.
    final container2 = containerWith(
      endpointStore: endpointStore,
      policyStore: policyStore,
    );
    final restored = container2.read(selectedEndpointProvider);
    expect(restored.tag, 'trojan-2');
    expect(restored.source, 'user');
  });

  test('selection of a group tag is allowed and persists', () async {
    final policyStore = PolicyStore(baseDir: dir.path);
    await policyStore.save(
      const PolicyDocument(
        groups: <OutboundGroup>[
          OutboundGroup.urlTest(
            tag: 'auto',
            members: <String>['trojan-1'],
          ),
        ],
        leafOutbounds: <String>['trojan-1'],
      ),
    );
    final endpointStore = EndpointStore(baseDir: dir.path);
    await endpointStore.save(<StoredEndpoint>[trojan('trojan-1')]);

    final container = containerWith(
      endpointStore: endpointStore,
      policyStore: policyStore,
    );
    await container.read(selectedEndpointProvider.notifier).select('auto');
    final picked = container.read(selectedEndpointProvider);
    expect(picked.tag, 'auto');
    expect(picked.source, 'user');
  });

  test('deleted selected endpoint clears the pick (no stale warning)',
      () async {
    final endpointStore = EndpointStore(baseDir: dir.path);
    await endpointStore.save(<StoredEndpoint>[
      trojan('trojan-1'),
      trojan('trojan-2'),
    ]);

    final container = containerWith(endpointStore: endpointStore);
    await container.read(selectedEndpointProvider.notifier).select('trojan-2');
    expect(container.read(selectedEndpointProvider).tag, 'trojan-2');

    // Deletion flow: clearInvalid removes the persisted pick.
    await container
        .read(selectedEndpointProvider.notifier)
        .clearInvalid('trojan-2');
    final after = container.read(selectedEndpointProvider);
    expect(after.tag, 'trojan-1'); // falls back to first endpoint
    expect(after.source, 'endpoint');
    expect(after.hadDeadTag, isFalse);
  });

  test('pick that dies without clearInvalid falls back with deadTag warning',
      () async {
    final endpointStore = EndpointStore(baseDir: dir.path);
    await endpointStore.save(<StoredEndpoint>[trojan('trojan-1')]);

    final container = containerWith(endpointStore: endpointStore);
    // Persist a pick for a tag that does not exist in the store.
    await container.read(selectedEndpointProvider.notifier).select('ghost');
    final selected = container.read(selectedEndpointProvider);
    expect(selected.tag, 'trojan-1');
    expect(selected.source, 'endpoint');
    expect(selected.deadTag, 'ghost');
    expect(selected.hadDeadTag, isTrue);
  });

  test('selection store round-trips and clears', () async {
    final store = SelectionStore(baseDir: dir.path);
    expect(store.read(), isNull);
    await store.save('trojan-9');
    expect(store.read(), 'trojan-9');
    await store.clear();
    expect(store.read(), isNull);
  });
}
