import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'routing_policy.dart';
import 'rules_controller.dart';

/// Rules tab: 30-field routing editor over the core fields. Rules compile
/// through the real compiler — the error card shows everything the engine
/// would reject, all at once.
class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RulesState state = ref.watch(rulesControllerProvider);
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.rulesTitle,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: l10n.rulesAdd,
                  onPressed: () => _editRule(context, ref, null, null),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (state.rules.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    l10n.rulesEmpty,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: state.rules.length,
                  itemBuilder: (BuildContext context, int index) {
                    final RouteRule rule = state.rules[index];
                    final summary = _summary(rule, l10n);
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          rule.isLogical ? Icons.merge : Icons.rule,
                          color: rule.outbound == 'BLOCK'
                              ? theme.colorScheme.error
                              : null,
                        ),
                        title: Text(summary),
                        subtitle: Text('→ ${rule.outbound ?? '(sub-rule)'}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Semantics(
                              button: true,
                              label: '${l10n.rulesEdit} $summary',
                              child: IconButton(
                                tooltip: '${l10n.rulesEdit} $summary',
                                icon: const Icon(Icons.edit),
                                onPressed: () =>
                                    _editRule(context, ref, index, rule),
                              ),
                            ),
                            Semantics(
                              button: true,
                              label: '${l10n.rulesDelete} $summary',
                              child: IconButton(
                                tooltip: '${l10n.rulesDelete} $summary',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => ref
                                    .read(rulesControllerProvider.notifier)
                                    .deleteRule(index),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (state.validationErrors.isNotEmpty)
              Semantics(
                liveRegion: true,
                child: Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.rulesValidationErrors,
                          style: theme.textTheme.titleSmall,
                        ),
                        for (final error in state.validationErrors)
                          Text(error, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _summary(RouteRule rule, AppLocalizations l10n) {
    final parts = <String>[
      if (rule.domains?.isNotEmpty ?? false) 'domain(${rule.domains!.length})',
      if (rule.domainSuffixes?.isNotEmpty ?? false)
        'suffix(${rule.domainSuffixes!.join(', ')})',
      if (rule.domainKeywords?.isNotEmpty ?? false)
        'kw(${rule.domainKeywords!.length})',
      if (rule.ipCidrs?.isNotEmpty ?? false) 'ip(${rule.ipCidrs!.length})',
      if (rule.ports?.isNotEmpty ?? false) 'port(${rule.ports!.join(',')})',
      if (rule.portRanges?.isNotEmpty ?? false)
        'range(${rule.portRanges!.join(',')})',
      if (rule.processNames?.isNotEmpty ?? false)
        'proc(${rule.processNames!.join(',')})',
      if (rule.ruleSets?.isNotEmpty ?? false)
        'set(${rule.ruleSets!.join(',')})',
      if (rule.clashMode != null) 'mode:${rule.clashMode}',
      if (rule.invert) 'invert',
    ];
    return parts.isEmpty ? l10n.rulesEmptyRule : parts.join(' · ');
  }

  Future<void> _editRule(
    BuildContext context,
    WidgetRef ref,
    int? index,
    RouteRule? existing,
  ) async {
    final RouteRule? result = await showModalBottomSheet<RouteRule>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _RuleFormSheet(existing: existing),
    );
    if (result == null) {
      return;
    }
    final RulesController controller = ref.read(
      rulesControllerProvider.notifier,
    );
    if (index == null) {
      await controller.addRule(result);
    } else {
      await controller.updateRule(index, result);
    }
  }
}

class _RuleFormSheet extends StatefulWidget {
  const _RuleFormSheet({required this.existing});

  final RouteRule? existing;

  @override
  State<_RuleFormSheet> createState() => _RuleFormSheetState();
}

class _RuleFormSheetState extends State<_RuleFormSheet> {
  String? _outbound;
  String? _clashMode;
  bool _invert = false;
  final TextEditingController _suffixes = TextEditingController();
  final TextEditingController _domains = TextEditingController();
  final TextEditingController _keywords = TextEditingController();
  final TextEditingController _ips = TextEditingController();
  final TextEditingController _ports = TextEditingController();
  final TextEditingController _portRanges = TextEditingController();
  final TextEditingController _processes = TextEditingController();
  final TextEditingController _ruleSets = TextEditingController();

  @override
  void initState() {
    super.initState();
    _outbound = widget.existing?.outbound ?? 'PROXY';
    _invert = widget.existing?.invert ?? false;
    _clashMode = widget.existing?.clashMode;
    _suffixes.text = widget.existing?.domainSuffixes?.join(', ') ?? '';
    _domains.text = widget.existing?.domains?.join(', ') ?? '';
    _keywords.text = widget.existing?.domainKeywords?.join(', ') ?? '';
    _ips.text = widget.existing?.ipCidrs?.join(', ') ?? '';
    _ports.text = widget.existing?.ports?.join(', ') ?? '';
    _portRanges.text = widget.existing?.portRanges?.join(', ') ?? '';
    _processes.text = widget.existing?.processNames?.join(', ') ?? '';
    _ruleSets.text = widget.existing?.ruleSets?.join(', ') ?? '';
    // Save enablement + the inline hint track typing; without this the
    // button state freezes at its first-build value.
    for (final c in <TextEditingController>[
      _suffixes,
      _domains,
      _keywords,
      _ips,
      _ports,
      _portRanges,
      _processes,
      _ruleSets,
    ]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _suffixes,
      _domains,
      _keywords,
      _ips,
      _ports,
      _portRanges,
      _processes,
      _ruleSets,
    ]) {
      c.removeListener(_onFieldChanged);
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool hasConditions = _hasConditions();
    return Padding(
      padding: EdgeInsetsDirectional.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              widget.existing == null ? l10n.rulesNew : l10n.rulesEdit,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _outbound,
              decoration: InputDecoration(
                labelText: l10n.rulesOutbound,
                border: const OutlineInputBorder(),
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: 'PROXY', child: Text('PROXY')),
                DropdownMenuItem<String>(
                  value: 'DIRECT',
                  child: Text('DIRECT'),
                ),
                DropdownMenuItem<String>(value: 'BLOCK', child: Text('BLOCK')),
                DropdownMenuItem<String>(
                  value: 'TOR-CHAIN',
                  child: Text('TOR-CHAIN'),
                ),
              ],
              onChanged: (String? value) => setState(() => _outbound = value),
            ),
            const SizedBox(height: 12),
            _field(
              controller: _suffixes,
              label: 'Domain suffixes (comma separated)',
              hint: 'cn, ru, local',
            ),
            _field(
              controller: _domains,
              label: 'Full domains (comma separated)',
              hint: 'example.com, api.vendor.io',
            ),
            _field(
              controller: _keywords,
              label: 'Domain keywords (comma separated)',
              hint: 'google, github',
            ),
            _field(
              controller: _ips,
              label: 'IP CIDRs (comma separated)',
              hint: '10.0.0.0/8, 192.168.0.0/16',
            ),
            _field(
              controller: _ports,
              label: 'Ports (comma separated)',
              hint: '443, 80',
            ),
            _field(
              controller: _portRanges,
              label: 'Port ranges (min:max, comma separated)',
              hint: '1000:2000, 50000:60000',
            ),
            _field(
              controller: _processes,
              label: 'Process names (comma separated)',
              hint: 'steam.exe, torrent.exe',
            ),
            _field(
              controller: _ruleSets,
              label: 'Rule sets (comma separated)',
              hint: 'geosite-cn, geoip-cn',
            ),
            DropdownButtonFormField<String>(
              initialValue: _clashMode,
              decoration: const InputDecoration(
                labelText: 'Clash mode (optional)',
                border: OutlineInputBorder(),
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: null, child: Text('Any')),
                DropdownMenuItem<String>(
                  value: 'Direct',
                  child: Text('Direct'),
                ),
                DropdownMenuItem<String>(
                  value: 'Global',
                  child: Text('Global'),
                ),
              ],
              onChanged: (String? value) => setState(() => _clashMode = value),
            ),
            SwitchListTile(
              title: const Text('Invert match'),
              value: _invert,
              onChanged: (bool value) => setState(() => _invert = value),
            ),
            if (!hasConditions)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 8),
                  child: Text(
                    l10n.rulesNeedCondition,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.rulesCancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: hasConditions
                      ? () {
                          Navigator.of(context).pop(
                            RouteRule(
                              outbound: _outbound,
                              domains: _split(_domains),
                              domainSuffixes: _split(_suffixes),
                              domainKeywords: _split(_keywords),
                              ipCidrs: _split(_ips),
                              ports: _split(_ports),
                              portRanges: _split(_portRanges),
                              processNames: _split(_processes),
                              ruleSets: _split(_ruleSets),
                              clashMode: _clashMode,
                              invert: _invert,
                            ),
                          );
                        }
                      : null,
                  child: Text(l10n.rulesSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// True when at least one match condition is set. Save stays disabled
  /// otherwise — the old code left Save enabled and silently discarded the
  /// tap, with zero feedback for keyboard/screen-reader users.
  bool _hasConditions() {
    bool any(TextEditingController c) => c.text.trim().isNotEmpty;
    return any(_domains) ||
        any(_suffixes) ||
        any(_keywords) ||
        any(_ips) ||
        any(_ports) ||
        any(_portRanges) ||
        any(_processes) ||
        any(_ruleSets) ||
        _clashMode != null;
  }

  static List<String> _split(TextEditingController c) => c.text
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
