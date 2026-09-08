import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/backup_service.dart';
import '../../../core/services/flag_secure.dart';
import '../../../l10n/app_localizations.dart';
import '../../routing/groups_controller.dart';
import '../../routing/rules_controller.dart';
import '../../vpn/amnezia/awg_profile_screen.dart';
import '../../vpn/logic/selected_endpoint.dart';
import 'endpoints_controller.dart';
import 'ingestion/ingestion_adapter.dart'
    show
        Hysteria2Endpoint,
        ShadowsocksEndpoint,
        SshEndpoint,
        TrojanEndpoint,
        TuicEndpoint,
        VlessEndpoint,
        VmessEndpoint,
        WireGuardEndpoint;

/// Endpoints tab: stored endpoint list + import box (share-link bundle,
/// single URI, clash yaml, sing-box json — content-sniffed by the adapter).
class EndpointsScreen extends ConsumerWidget {
  const EndpointsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final EndpointsState state = ref.watch(endpointsControllerProvider);
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
                    l10n.endpointsTitle,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: l10n.endpointsExportBackup,
                  onPressed: () => _exportBackup(context),
                  icon: const Icon(Icons.backup_outlined),
                ),
                IconButton(
                  tooltip: l10n.endpointsImportBackup,
                  onPressed: () => _importBackup(context, ref),
                  icon: const Icon(Icons.restore_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const _ImportBox(),
            if (state.error != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8),
                child: Semantics(
                  liveRegion: true,
                  label: state.error,
                  child: Text(
                    state.error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            // Managed subscriptions (audit W2.5): URL imports register here
            // and refresh daily with If-None-Match. Shows last refresh +
            // remove.
            const _SubscriptionsBar(),
            const SizedBox(height: 8),
            if (state.endpoints.isEmpty)
              Expanded(
                child: Center(
                  child: Text(l10n.endpointsEmpty, textAlign: TextAlign.center),
                ),
              )
            else
              Expanded(
                child: Builder(
                  builder: (BuildContext context) {
                    final SelectedEndpoint selected = ref.watch(
                      selectedEndpointProvider,
                    );
                    return Semantics(
                      liveRegion: true,
                      label: '${state.endpoints.length} ${l10n.endpointsTitle}',
                      child: ListView.builder(
                        itemCount: state.endpoints.length,
                        itemBuilder: (BuildContext context, int index) {
                          final StoredEndpoint stored = state.endpoints[index];
                          final bool isSelected =
                              selected.tag == stored.tag &&
                              selected.source == 'user';
                          return Card(
                            // Selected endpoint is visually pinned: the
                            // next connect uses this tag (audit W2.1).
                            color: isSelected
                                ? theme.colorScheme.secondaryContainer
                                : null,
                            child: ListTile(
                              onTap: () => ref
                                  .read(selectedEndpointProvider.notifier)
                                  .select(stored.tag),
                              leading: Icon(_iconFor(stored)),
                              title: Text(stored.label),
                              subtitle: Text(
                                '${_protocolName(stored)} · ${stored.sourceUrl ?? 'manual'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  if (isSelected)
                                    Semantics(
                                      button: true,
                                      label: l10n.endpointsSelected(
                                        stored.label,
                                      ),
                                      child: const Icon(
                                        Icons.check_circle,
                                      ),
                                    )
                                  else
                                    Semantics(
                                      button: true,
                                      label: l10n.endpointsSelect(
                                        stored.label,
                                      ),
                                      child: const Icon(
                                        Icons.radio_button_unchecked,
                                      ),
                                    ),
                                  Semantics(
                                    button: true,
                                    label:
                                        '${l10n.endpointsDelete} ${stored.label}',
                                    child: IconButton(
                                      tooltip:
                                          '${l10n.endpointsDelete} ${stored.label}',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () async {
                                        final String deletedTag = stored.tag;
                                        await ref
                                            .read(
                                              endpointsControllerProvider
                                                .notifier,
                                            )
                                            .delete(index);
                                        // A dead selection must not keep
                                        // the warning banner alive.
                                        await ref
                                            .read(
                                              selectedEndpointProvider
                                                .notifier,
                                            )
                                            .clearInvalid(deletedTag);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// User-facing protocol name — never the Dart class name.
  String _protocolName(StoredEndpoint stored) => switch (stored.endpoint) {
    WireGuardEndpoint() => 'AmneziaWG / WireGuard',
    VlessEndpoint() => 'VLESS',
    VmessEndpoint() => 'VMess',
    ShadowsocksEndpoint() => 'Shadowsocks',
    TrojanEndpoint() => 'Trojan',
    Hysteria2Endpoint() => 'Hysteria2',
    TuicEndpoint() => 'TUIC',
    SshEndpoint() => 'SSH',
  };

  IconData _iconFor(StoredEndpoint stored) => switch (stored.endpoint) {
    WireGuardEndpoint() => Icons.vpn_key,
    VlessEndpoint() || VmessEndpoint() => Icons.swap_horiz,
    ShadowsocksEndpoint() || TrojanEndpoint() => Icons.enhanced_encryption,
    Hysteria2Endpoint() || TuicEndpoint() => Icons.bolt,
    SshEndpoint() => Icons.terminal,
  };

  Future<void> _exportBackup(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final password = await _promptPassword(context, l10n.endpointsExportTitle);
    if (password == null || password.isEmpty || !context.mounted) {
      return;
    }
    try {
      // Encrypt before the dialog: the picker writes the bytes itself.
      final bytes = await BackupService().exportBytes(password);
      final target = await FilePicker.saveFile(
        dialogTitle: 'Export encrypted backup',
        fileName: 'yourvpn-backup.qnv',
        bytes: Uint8List.fromList(bytes),
        type: FileType.custom,
        allowedExtensions: const <String>['qnv'],
      );
      if (target != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.endpointsBackupWritten(bytes.length),
            ),
          ),
        );
      }
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(
            content: Text(l10n.endpointsExportFailed(error.toString())),
          ),
        );
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final List<PlatformFile> picked;
    try {
      picked = await FilePicker.pickFiles(
        dialogTitle: 'Import encrypted backup',
        type: FileType.custom,
        allowedExtensions: const <String>['qnv'],
      );
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(
            content: Text(l10n.endpointsImportFailed(error.toString())),
          ),
        );
      return;
    }
    if (picked.isEmpty) {
      return;
    }
    // first, not single: the platform dialog permits multi-select.
    final path = picked.first.path;
    if (path == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.endpointsNoReadablePath),
        ),
      );
      return;
    }
    if (!context.mounted) {
      return;
    }
    final password = await _promptPassword(context, l10n.endpointsImportTitle);
    if (password == null || password.isEmpty) {
      return;
    }
    try {
      final summary = await BackupService().import(path, password);
      // The import wrote every store file directly; pending 300ms debounced
      // saves from these controllers would overwrite the imported files,
      // and a stale in-memory state would silently revert them on the next
      // edit — flush then invalidate all four.
      ref
        ..read(groupsControllerProvider.notifier).flushPendingWrites()
        ..read(rulesControllerProvider.notifier).flushPendingWrites()
        ..read(endpointsControllerProvider.notifier).flushPendingWrites();
      ref
        ..invalidate(endpointsControllerProvider)
        ..invalidate(groupsControllerProvider)
        ..invalidate(rulesControllerProvider);
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.endpointsRestored(
              summary.endpoints,
              summary.groups,
              summary.rules,
            ),
          ),
        ),
      );
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(
            content: Text(l10n.endpointsImportFailed(error.toString())),
          ),
        );
    }
  }

  Future<String?> _promptPassword(BuildContext context, String title) {
    final controller = TextEditingController();
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    // Audit W3.5: the password field must not appear in screenshots or the
    // app switcher for the dialog's lifetime. The future completes when the
    // dialog pops, so disable fires right after — including on cancel.
    unawaited(FlagSecure.enable());
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.endpointsBackupPassword,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.endpointsCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.endpointsOk),
          ),
        ],
      ),
    ).whenComplete(FlagSecure.disable);
  }
}

/// Managed subscription list: one line per URL with its last refresh time
/// and a remove action (audit W2.5).
class _SubscriptionsBar extends ConsumerWidget {
  const _SubscriptionsBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptions = ref.watch(
      subscriptionStoreProvider,
    ).read();
    if (subscriptions.isEmpty) {
      return const SizedBox.shrink();
    }
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final sub in subscriptions)
            ListTile(
              dense: true,
              leading: const Icon(Icons.rss_feed),
              title: Text(
                sub.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                sub.lastRefresh == null
                    ? l10n.endpointsSubPending
                    : l10n.endpointsSubUpdated(
                  sub.lastRefresh!.toIso8601String().substring(0, 16),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: l10n.endpointsRemoveSubscription,
                icon: const Icon(Icons.link_off),
                onPressed: () async {
                  await ref.read(subscriptionStoreProvider).remove(sub.url);
                  ref.invalidate(subscriptionStoreProvider);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ImportBox extends ConsumerStatefulWidget {
  const _ImportBox();

  @override
  ConsumerState<_ImportBox> createState() => _ImportBoxState();
}

class _ImportBoxState extends ConsumerState<_ImportBox> {
  final TextEditingController _controller = TextEditingController();

  void _openAwgEditor(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => const AwgProfileSheet(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EndpointsState state = ref.watch(endpointsControllerProvider);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: _controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: l10n.endpointsImportHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Semantics(
              liveRegion: true,
              child: FilledButton.icon(
                onPressed: state.importing
                    ? null
                    : () async {
                        await ref
                            .read(endpointsControllerProvider.notifier)
                            .importText(_controller.text);
                        if (context.mounted) {
                          _controller.clear();
                        }
                      },
                icon: state.importing
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(l10n.endpointsImport),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _openAwgEditor(context),
              icon: const Icon(Icons.vpn_key),
              label: Text(l10n.endpointsAwgProfile),
            ),
          ],
        ),
      ],
    );
  }
}
