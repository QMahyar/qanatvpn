import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../routing/groups_controller.dart' show policyStoreProvider;
import '../../routing/routing_policy.dart' show OutboundGroup;
import '../repositories/endpoint_store.dart' show StoredEndpoint;
import '../repositories/endpoints_controller.dart' show endpointStoreProvider;
import '../repositories/selection_store.dart';

/// The tag the next connect uses. Resolution order:
/// 1. the user's persisted pick from the endpoints screen (source `user`)
///    — validated against live tags,
/// 2. the first group's default member or first member (3-tier choice)
///    — validated against live tags; urltest groups resolve to the group
///    tag (engine-side auto-select),
/// 3. the first stored endpoint,
/// 4. the vendored profile tag (`awg-hkg-02`, the actual endpoint tag in
///    `profiles/config.wg-awg.json`).
///
/// Candidates that no longer exist (deleted endpoint, renamed group member)
/// are skipped, and the skipped tag surfaces via [SelectedEndpoint.deadTag]
/// so the UI can warn instead of silently connecting elsewhere.
class SelectedEndpoint {
  const SelectedEndpoint({
    required this.tag,
    this.source = 'fallback',
    this.deadTag,
  });

  final String tag;

  /// Where the selection came from — `user`, `group`, `endpoint`, `fallback`.
  final String source;

  /// Requested tag that no longer resolves (deleted/renamed), if any.
  /// Non-null means the UI fell back — show a warning, not silence.
  final String? deadTag;

  bool get hadDeadTag => deadTag != null;
}

/// Vendored endpoint tag shipped in `profiles/config.wg-awg.json`.
const String vendoredEndpointTag = 'awg-hkg-02';

final selectionStoreProvider = Provider<SelectionStore>(
  (ref) => const SelectionStore(),
);

/// Writable selection: the endpoints screen persists a tag via [select],
/// deletion clears it via [clearInvalid]. Rebuilds revalidate against live
/// tags so a deleted/renamed selection falls back with a visible warning.
class SelectedEndpointNotifier extends Notifier<SelectedEndpoint> {
  @override
  SelectedEndpoint build() {
    final endpoints = ref.watch(endpointStoreProvider).read();
    final liveTags = <String>{...endpoints.map((e) => e.tag), 'DIRECT', 'BLOCK'};
    final groups = ref.watch(policyStoreProvider).read().groups;
    for (final group in groups) {
      liveTags.add(group.tag);
    }

    String? deadTag;
    SelectedEndpoint? resolve;

    // 1. The user's persisted pick wins when it still resolves.
    final saved = ref.watch(selectionStoreProvider).read();
    if (saved != null && saved.isNotEmpty) {
      if (liveTags.contains(saved)) {
        resolve = SelectedEndpoint(tag: saved, source: 'user');
      } else {
        deadTag ??= saved;
      }
    }

    // 2-4. Automatic chain (group → first endpoint → vendored).
    resolve ??= _autoResolve(liveTags, groups, endpoints, deadTag);
    if (resolve.deadTag == null && deadTag != null) {
      return SelectedEndpoint(
        tag: resolve.tag,
        source: resolve.source,
        deadTag: deadTag,
      );
    }
    return resolve;
  }

  SelectedEndpoint _autoResolve(
    Set<String> liveTags,
    List<OutboundGroup> groups,
    List<StoredEndpoint> endpoints,
    String? deadTag,
  ) {
    for (final group in groups) {
      // Urltest groups auto-select engine-side: the shipped config carries
      // the group and its interval probe, so connecting to the group tag
      // lets the engine pick the best member (and fail over) — members
      // .first would pin a fixed node and defeat the urltest semantics.
      final candidates = <String?>[
        if (group.isUrlTest) group.tag,
        group.defaultMember,
        if (group.members.isNotEmpty) group.members.first,
      ];
      for (final tag in candidates) {
        if (tag == null || tag.isEmpty) {
          continue;
        }
        if (tag == 'DIRECT' || liveTags.contains(tag)) {
          return SelectedEndpoint(tag: tag, source: 'group', deadTag: deadTag);
        }
        deadTag ??= tag;
      }
    }
    if (endpoints.isNotEmpty) {
      return SelectedEndpoint(
        tag: endpoints.first.tag,
        source: 'endpoint',
        deadTag: deadTag,
      );
    }
    return SelectedEndpoint(tag: vendoredEndpointTag, deadTag: deadTag);
  }

  /// Persists the user's pick. Any live tag is accepted (endpoints, groups,
  /// DIRECT/BLOCK); validation happens on rebuild — a pick that dies later
  /// falls back with a warning rather than failing to connect.
  Future<void> select(String tag) async {
    await ref.read(selectionStoreProvider).save(tag);
    ref.invalidateSelf();
  }

  /// Clears a selection that no longer resolves (called on delete) so the
  /// warning banner does not outlive the dead tag.
  Future<void> clearInvalid(String deadTag) async {
    if (ref.read(selectionStoreProvider).read() == deadTag) {
      await ref.read(selectionStoreProvider).clear();
      ref.invalidateSelf();
    }
  }

  /// Test helper: force a rebuild without a persisted change.
  @override
  bool updateShouldNotify(SelectedEndpoint old, SelectedEndpoint next) =>
      old.tag != next.tag || old.source != next.source || old.deadTag != next.deadTag;
}

final selectedEndpointProvider =
    NotifierProvider<SelectedEndpointNotifier, SelectedEndpoint>(
      SelectedEndpointNotifier.new,
    );
