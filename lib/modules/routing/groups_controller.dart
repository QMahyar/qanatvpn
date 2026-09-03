import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'policy_store.dart';
import 'routing_policy.dart';
import 'routing_compiler.dart';

/// Known member universe for the picker: other groups + leaf endpoint tags
/// + DIRECT (+ TOR-CHAIN when a chain exists — the endpoint layer owns that).
final policyStoreProvider = Provider<PolicyStore>((ref) => const PolicyStore());

class GroupsState {
  const GroupsState({
    this.groups = const <OutboundGroup>[],
    this.leafOutbounds = const <String>[],
    this.validationErrors = const <String>[],
  });

  final List<OutboundGroup> groups;
  final List<String> leafOutbounds;
  final List<String> validationErrors;

  bool get isValid => validationErrors.isEmpty;

  /// Tag universe every group member must come from.
  Set<String> knownTags() => <String>{
    ...leafOutbounds,
    'DIRECT',
    for (final g in groups) g.tag,
  };
}

/// CRUD over the stored groups; every mutation validates through the real
/// compiler so the screen shows the same errors the engine would FATAL on.
class GroupsController extends Notifier<GroupsState> {
  @override
  GroupsState build() {
    final doc = ref.watch(policyStoreProvider).read();
    return _validated(doc.groups, doc.leafOutbounds);
  }

  GroupsState _validated(List<OutboundGroup> groups, List<String> leaves) {
    final compiled = const RoutingCompiler().compile(
      RoutingPolicy(rules: const <RouteRule>[], groups: groups),
    );
    return GroupsState(
      groups: groups,
      leafOutbounds: leaves,
      validationErrors: compiled.validationErrors,
    );
  }

  Future<void> _persist(List<OutboundGroup> groups) async {
    final store = ref.read(policyStoreProvider);
    final leaves = state.leafOutbounds;
    await store.save(PolicyDocument(groups: groups, leafOutbounds: leaves));
    state = _validated(groups, leaves);
  }

  Future<void> addGroup(OutboundGroup group) async {
    await _persist(<OutboundGroup>[...state.groups, group]);
  }

  Future<void> updateGroup(int index, OutboundGroup group) async {
    final next = <OutboundGroup>[...state.groups];
    if (index < 0 || index >= next.length) {
      return;
    }
    next[index] = group;
    await _persist(next);
  }

  Future<void> deleteGroup(int index) async {
    final next = <OutboundGroup>[...state.groups];
    if (index < 0 || index >= next.length) {
      return;
    }
    next.removeAt(index);
    await _persist(next);
  }
}

final groupsControllerProvider =
    NotifierProvider<GroupsController, GroupsState>(GroupsController.new);
