import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'diagnostics_controller.dart';
import 'health.dart';

/// Diagnostics tab: live 0-6 health score, DNS hijack state, TCP ping,
/// stability window. Probes run every 10s while the tab is open.
class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HealthReport? report = ref.watch(diagnosticsControllerProvider);
    final ThemeData theme = Theme.of(context);

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
                    'Diagnostics',
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () => ref
                      .read(diagnosticsControllerProvider.notifier)
                      .refreshNow(),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (report == null)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView(
                  children: <Widget>[
                    _ScoreCard(report: report),
                    const SizedBox(height: 12),
                    _ProbeTile(
                      icon: Icons.dns,
                      title: 'DNS hijack',
                      subtitle: report.hijacked
                          ? 'Tunnel resolver answering (FakeIP pool)'
                          : 'ISP resolver answering — tunnel likely down',
                      good: report.hijacked,
                    ),
                    _ProbeTile(
                      icon: Icons.speed,
                      title: 'Ping (TCP 1.1.1.1:443)',
                      subtitle: report.pingMs == null
                          ? 'unreachable'
                          : '${report.pingMs} ms',
                      good: report.pingMs != null,
                    ),
                    _ProbeTile(
                      icon: Icons.query_stats,
                      title: 'Stability window',
                      subtitle: '${report.stability}% of last probes OK',
                      good: report.stability >= 80,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.report});

  final HealthReport report;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      color: report.score >= 4
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.monitor_heart,
              size: 40,
              color: report.score >= 4
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${report.score} / 6 — ${report.level.name}',
                    style: theme.textTheme.titleLarge,
                  ),
                  Text(
                    'hierarchical score: logs → ping → stability',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProbeTile extends StatelessWidget {
  const _ProbeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.good,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: good ? theme.colorScheme.primary : theme.colorScheme.error,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(
          good ? Icons.check_circle : Icons.cancel,
          color: good ? theme.colorScheme.primary : theme.colorScheme.error,
        ),
      ),
    );
  }
}
