import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/persistence/debounced_saver.dart';
import '../vpn/repositories/endpoints_controller.dart'
    show endpointStoreProvider;
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
/// Leaf tags come from the endpoint store — imported endpoints are instantly
/// selectable as group members.
class GroupsController extends Notifier<GroupsState> {
  final DebouncedSaver _saver = DebouncedSaver();

  @override
  GroupsState build() {
    ref.onDispose(_saver.dispose);
    final doc = ref.watch(policyStoreProvider).read();
    final leaves = _leafTags();
    final groups = doc.groups;
    return _validated(groups, leaves);
  }

  /// Runs the debounced disk write now instead of after the delay.
  /// Production use: external writes to the store files (backup import)
  /// flush first so a pending save cannot overwrite them.
  Future<void> flushPendingWrites() => _saver.flush();

  /// Tests: run the debounced disk write now instead of after the delay.
  @visibleForTesting
  Future<void> flushPending() => flushPendingWrites();

  /// Endpoint tags are the live leaf universe; stored doc leaves kept for
  /// backward compatibility but endpoints always win.
  List<String> _leafTags() {
    final endpointTags = ref
        .watch(endpointStoreProvider)
        .read()
        .map((e) => e.tag)
        .toList();
    if (endpointTags.isNotEmpty) {
      return endpointTags;
    }
    return ref.read(policyStoreProvider).read().leafOutbounds;
  }

  GroupsState _validated(List<OutboundGroup> groups, List<String> leaves) {
    final compiled = const RoutingCompiler().compile(
      RoutingPolicy(
        rules: const <RouteRule>[],
        groups: groups,
        leafOutbounds: leaves,
      ),
    );
    return GroupsState(
      groups: groups,
      leafOutbounds: leaves,
      validationErrors: compiled.validationErrors,
    );
  }

  Future<void> _persist(List<OutboundGroup> groups) async {
    final store = ref.read(policyStoreProvider);
    final leaves = _leafTags();
    state = _validated(groups, leaves);
    final doc = PolicyDocument(groups: groups, leafOutbounds: leaves);
    _saver.schedule(() => store.save(doc));
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
