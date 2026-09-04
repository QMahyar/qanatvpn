import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/tunnel.dart';
import '../../../../l10n/app_localizations.dart';
import '../../updates/updates_controller.dart' as updates;
import '../logic/selected_endpoint.dart';
import '../logic/tunnel_l10n.dart';
import '../logic/vpn_notifier.dart';
import '../repositories/endpoints_controller.dart';

/// Bento home: power tile + state tile + endpoint tile + quick tiles.
/// Adaptive 4→2 column at 40rem, 1 column under 20rem.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VpnState vpn = ref.watch(vpnNotifierProvider);
    final ThemeData theme = Theme.of(context);
    final double width = MediaQuery.sizeOf(context).width;
    final int columns = width >= 640 ? 4 : (width >= 320 ? 2 : 1);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.all(8),
              child: Text('YOURVPN', style: theme.textTheme.headlineMedium),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return GridView.count(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: <Widget>[
                      PowerTile(phase: vpn.phase),
                      StateTile(vpn: vpn),
                      const EndpointTile(),
                      const SplitTile(),
                      const StatsTile(),
                      const UpdateTile(),
                      const WizardTile(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PowerTile extends ConsumerWidget {
  const PowerTile({super.key, required this.phase});

  final TunnelState phase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool connected = phase == TunnelState.connected;
    final bool busy =
        phase == TunnelState.connecting || phase == TunnelState.disconnecting;
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    // Honor the OS "remove animations" setting: rotation snaps instead of
    // spinning for vestibular safety.
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      label: connected ? l10n.disconnect : l10n.connect,
      child: Card(
        color: connected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        child: InkWell(
          onTap: busy
              ? null
              : () async {
                  final VpnNotifier notifier = ref.read(
                    vpnNotifierProvider.notifier,
                  );
                  if (connected) {
                    await notifier.disconnect();
                  } else {
                    await notifier.connect(
                      ref.read(selectedEndpointProvider).tag,
                    );
                  }
                },
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedRotation(
                  turns: connected ? 0.5 : 0,
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 350),
                  curve: reduceMotion ? Curves.linear : Curves.easeOutBack,
                  child: Icon(
                    Icons.power_settings_new,
                    size: 56,
                    color: connected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(phase.label(l10n)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StateTile extends StatelessWidget {
  const StateTile({super.key, required this.vpn});

  final VpnState vpn;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Card(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              switch (vpn.phase) {
                TunnelState.connected => Icons.shield,
                TunnelState.blocked => Icons.gpp_bad,
                _ => Icons.shield_outlined,
              },
              size: 32,
              color: vpn.phase == TunnelState.blocked
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(vpn.tag ?? 'no endpoint', style: theme.textTheme.titleMedium),
            if (vpn.blockReason != null)
              Text(
                vpn.blockReason!.label(l10n),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class EndpointTile extends ConsumerWidget {
  const EndpointTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final EndpointsState state = ref.watch(endpointsControllerProvider);
    final SelectedEndpoint selected = ref.watch(selectedEndpointProvider);
    final String label =
        selected.source == 'fallback' && state.endpoints.isEmpty
        ? 'No endpoints'
        : selected.tag;
    final String sub = selected.hadDeadTag
        ? '“${selected.deadTag}” gone — using ${selected.tag}'
        : state.endpoints.isEmpty
        ? 'Tap to import'
        : '${state.endpoints.length} stored · connect: ${selected.source}';
    final ThemeData theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Endpoints',
      child: Card(
        child: InkWell(
          onTap: () => GoRouter.of(context).go('/endpoints'),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.dns, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(sub, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SplitTile extends StatelessWidget {
  const SplitTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => GoRouter.of(context).go('/rules'),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.rule, size: 32),
              SizedBox(height: 8),
              Text('Split rules'),
            ],
          ),
        ),
      ),
    );
  }
}

class StatsTile extends StatelessWidget {
  const StatsTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.speed, size: 32),
            SizedBox(height: 8),
            Text('0 B / 0 B'),
          ],
        ),
      ),
    );
  }
}

class WizardTile extends StatelessWidget {
  const WizardTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => GoRouter.of(context).go('/home'),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.auto_fix_high, size: 32),
              SizedBox(height: 8),
              Text('Setup guide'),
            ],
          ),
        ),
      ),
    );
  }
}

class UpdateTile extends ConsumerWidget {
  const UpdateTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updates.UpdateState state = ref.watch(
      updates.updateControllerProvider,
    );
    final bool available = state is updates.UpdateAvailable;
    final String label = switch (state) {
      updates.UpdateAvailable(:final info) => 'Update ${info.version}',
      _ => 'Updates',
    };
    final ThemeData theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Updates',
      child: Card(
        color: available ? theme.colorScheme.tertiaryContainer : null,
        child: InkWell(
          onTap: () => GoRouter.of(context).go('/updates'),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  available ? Icons.system_update_alt : Icons.system_update,
                  size: 32,
                  color: available ? theme.colorScheme.primary : null,
                ),
                const SizedBox(height: 8),
                Text(label, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
