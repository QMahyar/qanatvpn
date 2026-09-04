import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'groups_controller.dart';
import 'routing_policy.dart';

/// Groups tab: outbound-group CRUD (selector/urltest) with live validation.
/// Members are picked from the known tag universe (groups, endpoint leaves,
/// DIRECT); the compiler surfaces every broken reference at once.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GroupsState state = ref.watch(groupsControllerProvider);
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
                    l10n.groupsTitle,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: l10n.groupsAdd,
                  onPressed: () => _editGroup(context, ref, null, null),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (state.groups.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    l10n.groupsEmpty,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: state.groups.length,
                  itemBuilder: (BuildContext context, int index) {
                    final OutboundGroup group = state.groups[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          group.isUrlTest ? Icons.speed : Icons.low_priority,
                        ),
                        title: Text(group.tag),
                        subtitle: Text(
                          group.isUrlTest
                              ? 'urltest · ${group.members.length} members'
                              : 'selector · ${group.members.length} members',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Semantics(
                              button: true,
                              label: '${l10n.groupsEdit} ${group.tag}',
                              child: IconButton(
                                tooltip: '${l10n.groupsEdit} ${group.tag}',
                                icon: const Icon(Icons.edit),
                                onPressed: () =>
                                    _editGroup(context, ref, index, group),
                              ),
                            ),
                            Semantics(
                              button: true,
                              label: '${l10n.groupsDelete} ${group.tag}',
                              child: IconButton(
                                tooltip:
                                    '${l10n.groupsDelete} ${group.tag}',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => ref
                                    .read(groupsControllerProvider.notifier)
                                    .deleteGroup(index),
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
                          l10n.groupsValidationErrors,
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

  Future<void> _editGroup(
    BuildContext context,
    WidgetRef ref,
    int? index,
    OutboundGroup? existing,
  ) async {
    final GroupsState state = ref.read(groupsControllerProvider);
    final OutboundGroup? result = await showModalBottomSheet<OutboundGroup>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _GroupFormSheet(
        existing: existing,
        knownTags: state.knownTags(),
        otherGroupTags: <String>{
          for (final group in state.groups)
            if (group.tag != existing?.tag) group.tag,
        },
      ),
    );
    if (result == null) {
      return;
    }
    final GroupsController controller = ref.read(
      groupsControllerProvider.notifier,
    );
    if (index == null) {
      await controller.addGroup(result);
    } else {
      await controller.updateGroup(index, result);
    }
  }
}

class _GroupFormSheet extends StatefulWidget {
  const _GroupFormSheet({
    required this.existing,
    required this.knownTags,
    required this.otherGroupTags,
  });

  final OutboundGroup? existing;
  final Set<String> knownTags;
  final Set<String> otherGroupTags;

  @override
  State<_GroupFormSheet> createState() => _GroupFormSheetState();
}

class _GroupFormSheetState extends State<_GroupFormSheet> {
  late bool _isUrlTest = widget.existing?.isUrlTest ?? false;
  late final TextEditingController _tagController = TextEditingController(
    text: widget.existing?.tag ?? '',
  );
  late final TextEditingController _urlController = TextEditingController(
    text: widget.existing?.url ?? 'https://www.gstatic.com/generate_204',
  );
  late final TextEditingController _intervalController = TextEditingController(
    text: widget.existing?.interval == null
        ? '5'
        : widget.existing!.interval!.inMinutes.toString(),
  );
  late final TextEditingController _toleranceController =
      TextEditingController(
        text: widget.existing?.tolerance?.toString() ?? '50',
      );
  late final Set<String> _members = <String>{...?widget.existing?.members};
  String? _defaultMember;

  @override
  void initState() {
    super.initState();
    _defaultMember = widget.existing?.defaultMember;
  }

  @override
  void dispose() {
    _tagController.dispose();
    _urlController.dispose();
    _intervalController.dispose();
    _toleranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool editingExisting = widget.existing != null;
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
              editingExisting ? 'Edit group' : 'New group',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(value: false, label: Text('Selector')),
                ButtonSegment<bool>(value: true, label: Text('Urltest')),
              ],
              selected: <bool>{_isUrlTest},
              onSelectionChanged: (Set<bool> selection) =>
                  setState(() => _isUrlTest = selection.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagController,
              decoration: const InputDecoration(
                labelText: 'Tag',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text('Members', style: theme.textTheme.titleSmall),
            for (final tag in widget.knownTags)
              CheckboxListTile(
                dense: true,
                title: Text(tag),
                value: _members.contains(tag),
                onChanged: (bool? checked) => setState(() {
                  checked! ? _members.add(tag) : _members.remove(tag);
                }),
              ),
            if (!_isUrlTest) ...<Widget>[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _defaultMember,
                decoration: const InputDecoration(
                  labelText: 'Default member (optional)',
                  border: OutlineInputBorder(),
                ),
                items: <DropdownMenuItem<String>>[
                  for (final tag in _members)
                    DropdownMenuItem<String>(value: tag, child: Text(tag)),
                ],
                onChanged: (String? value) =>
                    setState(() => _defaultMember = value),
              ),
            ] else ...<Widget>[
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Probe URL',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _intervalController,
                      decoration: const InputDecoration(
                        labelText: 'Interval (minutes)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _toleranceController,
                      decoration: const InputDecoration(
                        labelText: 'Tolerance (ms)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _members.isEmpty || _tagController.text.isEmpty
                      ? null
                      : () {
                          final String tag = _tagController.text.trim();
                          if (_isUrlTest) {
                            final intervalMinutes =
                                int.tryParse(_intervalController.text.trim()) ??
                                5;
                            final tolerance =
                                int.tryParse(_toleranceController.text.trim()) ??
                                50;
                            Navigator.of(context).pop(
                              OutboundGroup.urlTest(
                                tag: tag,
                                members: _members.toList(),
                                url: _urlController.text.trim(),
                                interval: Duration(minutes: intervalMinutes),
                                tolerance: tolerance,
                              ),
                            );
                          } else {
                            Navigator.of(context).pop(
                              OutboundGroup.selector(
                                tag: tag,
                                members: _members.toList(),
                                defaultMember: _defaultMember,
                              ),
                            );
                          }
                        },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
