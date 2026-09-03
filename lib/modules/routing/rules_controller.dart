import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  @override
  RulesState build() {
    final doc = ref.watch(ruleStoreProvider).read();
    return _validated(doc.rules);
  }

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
    final store = ref.read(ruleStoreProvider);
    await store.save(RuleDocument(rules: rules));
    state = _validated(rules);
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
