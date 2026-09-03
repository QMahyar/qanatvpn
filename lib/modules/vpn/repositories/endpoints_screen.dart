import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Endpoints', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            const _ImportBox(),
            if (state.error != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8),
                child: Text(
                  state.error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (state.endpoints.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No endpoints. Paste a share link or subscription URL '
                    'above.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: state.endpoints.length,
                  itemBuilder: (BuildContext context, int index) {
                    final StoredEndpoint stored = state.endpoints[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(_iconFor(stored)),
                        title: Text(stored.label),
                        subtitle: Text(
                          '${stored.endpoint.runtimeType} · ${stored.sourceUrl ?? 'manual'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => ref
                              .read(endpointsControllerProvider.notifier)
                              .delete(index),
                        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: _controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'vless://… vmess://… https://sub.example.com …',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            FilledButton.icon(
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
              label: const Text('Import'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _openAwgEditor(context),
              icon: const Icon(Icons.vpn_key),
              label: const Text('AWG profile'),
            ),
          ],
        ),
      ],
    );
  }
}
