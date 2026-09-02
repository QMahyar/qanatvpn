import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/tunnel.dart';
import '../logic/vpn_notifier.dart';

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
              child: Text(
                'YOURVPN',
                style: theme.textTheme.headlineMedium,
              ),
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
    return Semantics(
      button: true,
      label: connected ? 'Disconnect' : 'Connect',
      child: Card(
        color: connected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        child: InkWell(
          onTap: busy
              ? null
              : () async {
                  final VpnNotifier notifier =
                      ref.read(vpnNotifierProvider.notifier);
                  if (connected) {
                    await notifier.disconnect();
                  } else {
                    await notifier.connect('HKG-02');
                  }
                },
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedRotation(
                  turns: connected ? 0.5 : 0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    Icons.power_settings_new,
                    size: 56,
                    color: connected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  switch (phase) {
                    TunnelState.connected => 'Connected',
                    TunnelState.connecting => 'Connecting…',
                    TunnelState.disconnecting => 'Disconnecting…',
                    TunnelState.blocked => 'Blocked',
                    TunnelState.reconnecting => 'Reconnecting…',
                    TunnelState.disconnected => 'Tap to connect',
                  },
                ),
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
                vpn.blockReason!.name,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}

class EndpointTile extends StatelessWidget {
  const EndpointTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.dns, size: 32),
            SizedBox(height: 8),
            Text('HKG-02'),
            Text('AWG · 1408 MTU'),
          ],
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

