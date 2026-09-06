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
            child: SingleChildScrollView(
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
        child: SingleChildScrollView(
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
              Text(
                vpn.tag ?? l10n.homeNoEndpoint,
                style: theme.textTheme.titleMedium,
              ),
              if (vpn.blockReason != null)
                Text(
                  vpn.blockReason!.label(l10n),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              if (vpn.blockDetail != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 4),
                  child: Text(
                    // Engine FATAL/exception text (audit W2.7) — clamped
                    // so a long engine dump cannot blow the tile layout.
                    vpn.blockDetail!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
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
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String label =
        selected.source == 'fallback' && state.endpoints.isEmpty
        ? l10n.homeNoEndpoints
        : selected.tag;
    final String sub = selected.hadDeadTag
        ? l10n.homeDeadTag(selected.deadTag ?? '', selected.tag)
        : state.endpoints.isEmpty
        ? l10n.homeTapToImport
        : l10n.homeStoredSuffix(state.endpoints.length, selected.source);
    final ThemeData theme = Theme.of(context);
    return Semantics(
      button: true,
      label: l10n.homeEndpoints,
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
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      label: l10n.homeSplitRules,
      child: Card(
        child: InkWell(
          onTap: () => GoRouter.of(context).go('/rules'),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.rule, size: 32),
                const SizedBox(height: 8),
                Text(l10n.homeSplitRules),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Connect-metrics tile: shows the last connect's phase timings from
/// [Tunnel.lastConnectMetrics]. Publish ordering guarantees completeness —
/// the tunnel publishes metrics BEFORE emitting connected, so a tile
/// rebuilt on the connected transition reads a full report. Engine-managed
/// TUN (both platforms) means establish/protect keys are often absent —
/// the tile renders only the phases that exist.
class StatsTile extends ConsumerWidget {
  const StatsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vpn = ref.watch(vpnNotifierProvider);
    final metrics = ref.watch(tunnelProvider).lastConnectMetrics;
    final ThemeData theme = Theme.of(context);
    final String headline;
    if (vpn.phase != TunnelState.connected || metrics == null) {
      headline = metrics == null ? 'No connect yet' : 'Disconnected';
    } else {
      headline = 'connect ${metrics.total.inMilliseconds} ms';
    }
    final phases = metrics?.phases.entries
        .map((entry) => '${entry.key} ${entry.value.inMilliseconds}ms')
        .take(3)
        .toList();
    return Semantics(
      label: 'Connect metrics: $headline',
      child: Card(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.speed, size: 32),
                const SizedBox(height: 8),
                Text(headline, textAlign: TextAlign.center),
                if (phases != null && vpn.phase == TunnelState.connected)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 4),
                    child: Text(
                      phases.join(' · '),
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WizardTile extends StatelessWidget {
  const WizardTile({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      label: l10n.homeSetupGuide,
      child: Card(
        child: InkWell(
          onTap: () => GoRouter.of(context).go('/home'),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.auto_fix_high, size: 32),
                const SizedBox(height: 8),
                Text(l10n.homeSetupGuide),
              ],
            ),
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
