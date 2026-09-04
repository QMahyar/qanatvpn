import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/persistence/debounced_saver.dart';
import 'routing_compiler.dart';
import 'rule_store.dart';
import 'routing_policy.dart';

final ruleStoreProvider = Provider<RuleStore>((ref) => const RuleStore());

class RulesState {
  const RulesState({
    this.rules = const <RouteRule>[],
    this.validationErrors = const <String>[],
  });

  final List<RouteRule> rules;
  final List<String> validationErrors;

  bool get isValid => validationErrors.isEmpty;
}

/// CRUD over the stored rules; every mutation validates through the real
/// compiler so the screen shows exactly what the engine would reject.
class RulesController extends Notifier<RulesState> {
  final DebouncedSaver _saver = DebouncedSaver();

  @override
  RulesState build() {
    ref.onDispose(_saver.dispose);
    final doc = ref.watch(ruleStoreProvider).read();
    return _validated(doc.rules);
  }

  /// Runs the debounced disk write now instead of after the delay.
  /// Production use: external writes to the store files (backup import)
  /// flush first so a pending save cannot overwrite them.
  Future<void> flushPendingWrites() => _saver.flush();

  /// Tests: run the debounced disk write now instead of after the delay.
  @visibleForTesting
  Future<void> flushPending() => flushPendingWrites();

  RulesState _validated(List<RouteRule> rules) {
    final compiled = const RoutingCompiler().compile(
      RoutingPolicy(rules: rules),
    );
    return RulesState(
      rules: rules,
      validationErrors: compiled.validationErrors,
    );
  }

  Future<void> _persist(List<RouteRule> rules) async {
    // UI updates now; only the disk write debounces. The closure captures
    // the full next list (not a delta) so coalesced writes never lose edits.
    state = _validated(rules);
    final store = ref.read(ruleStoreProvider);
    final doc = RuleDocument(rules: rules);
    _saver.schedule(() => store.save(doc));
  }

  Future<void> addRule(RouteRule rule) async {
    await _persist(<RouteRule>[...state.rules, rule]);
  }

  Future<void> updateRule(int index, RouteRule rule) async {
    final next = <RouteRule>[...state.rules];
    if (index < 0 || index >= next.length) {
      return;
    }
    next[index] = rule;
    await _persist(next);
  }

  Future<void> deleteRule(int index) async {
    final next = <RouteRule>[...state.rules];
    if (index < 0 || index >= next.length) {
      return;
    }
    next.removeAt(index);
    await _persist(next);
  }
}

final rulesControllerProvider = NotifierProvider<RulesController, RulesState>(
  RulesController.new,
);
