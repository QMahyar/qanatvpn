import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../routing/groups_controller.dart' show policyStoreProvider;
import '../repositories/endpoints_controller.dart' show endpointStoreProvider;

/// The tag the next connect uses. Resolution order:
/// 1. the first group's default member or first member (user's 3-tier
///    choice wins),
/// 2. the first stored endpoint,
/// 3. the vendored profile tag.
class SelectedEndpoint {
  const SelectedEndpoint({required this.tag, this.source = 'fallback'});

  final String tag;

  /// Where the selection came from — `group`, `endpoint`, `fallback`.
  final String source;
}

final selectedEndpointProvider = Provider<SelectedEndpoint>((ref) {
  final groups = ref.watch(policyStoreProvider).read().groups;
  for (final group in groups) {
    final tag =
        group.defaultMember ??
        (group.members.isEmpty ? null : group.members.first);
    if (tag != null && tag.isNotEmpty) {
      return SelectedEndpoint(tag: tag, source: 'group');
    }
  }
  final endpoints = ref.watch(endpointStoreProvider).read();
  if (endpoints.isNotEmpty) {
    return SelectedEndpoint(tag: endpoints.first.tag, source: 'endpoint');
  }
  return const SelectedEndpoint(tag: 'HKG-02');
});
