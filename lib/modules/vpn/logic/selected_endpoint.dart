import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../routing/groups_controller.dart' show policyStoreProvider;
import '../repositories/endpoints_controller.dart' show endpointStoreProvider;

/// The tag the next connect uses. Resolution order:
/// 1. the first group's default member or first member (user's 3-tier
///    choice wins) — validated against live tags,
/// 2. the first stored endpoint,
/// 3. the vendored profile tag (`awg-hkg-02`, the actual endpoint tag in
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

  /// Where the selection came from — `group`, `endpoint`, `fallback`.
  final String source;

  /// Requested tag that no longer resolves (deleted/renamed), if any.
  /// Non-null means the UI fell back — show a warning, not silence.
  final String? deadTag;

  bool get hadDeadTag => deadTag != null;
}

/// Vendored endpoint tag shipped in `profiles/config.wg-awg.json`.
const String vendoredEndpointTag = 'awg-hkg-02';

final selectedEndpointProvider = Provider<SelectedEndpoint>((ref) {
  final endpoints = ref.watch(endpointStoreProvider).read();
  final liveTags = <String>{
    ...endpoints.map((e) => e.tag),
    'DIRECT',
    'BLOCK',
  };
  String? deadTag;
  final groups = ref.watch(policyStoreProvider).read().groups;
  for (final group in groups) {
    liveTags.add(group.tag);
  }
  for (final group in groups) {
    final candidates = <String?>[
      group.defaultMember,
      if (group.members.isNotEmpty) group.members.first,
    ];
    for (final tag in candidates) {
      if (tag == null || tag.isEmpty) {
        continue;
      }
      if (tag == 'DIRECT' || liveTags.contains(tag)) {
        return SelectedEndpoint(tag: tag, source: 'group');
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
  return SelectedEndpoint(
    tag: vendoredEndpointTag,
    deadTag: deadTag,
  );
});
