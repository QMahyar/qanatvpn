import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../vpn/amnezia/awg_profile_screen.dart';
import 'endpoints_controller.dart';
import 'ingestion/ingestion_adapter.dart'
    show
        Hysteria2Endpoint,
        ShadowsocksEndpoint,
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
            Text(l10n.endpointsTitle, style: theme.textTheme.headlineSmall),
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
            if (state.endpoints.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    l10n.endpointsEmpty,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  label:
                      '${state.endpoints.length} ${l10n.endpointsTitle}',
                  child: ListView.builder(
                    itemCount: state.endpoints.length,
                    itemBuilder: (BuildContext context, int index) {
                      final StoredEndpoint stored = state.endpoints[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(_iconFor(stored)),
                          title: Text(stored.label),
                          subtitle: Text(
                            '${_protocolName(stored)} · ${stored.sourceUrl ?? 'manual'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Semantics(
                            button: true,
                            label:
                                '${l10n.endpointsDelete} ${stored.label}',
                            child: IconButton(
                              tooltip:
                                  '${l10n.endpointsDelete} ${stored.label}',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => ref
                                  .read(
                                    endpointsControllerProvider.notifier,
                                  )
                                  .delete(index),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
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
  };

  IconData _iconFor(StoredEndpoint stored) => switch (stored.endpoint) {
    WireGuardEndpoint() => Icons.vpn_key,
    VlessEndpoint() || VmessEndpoint() => Icons.swap_horiz,
    ShadowsocksEndpoint() || TrojanEndpoint() => Icons.enhanced_encryption,
    Hysteria2Endpoint() || TuicEndpoint() => Icons.bolt,
  };
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
