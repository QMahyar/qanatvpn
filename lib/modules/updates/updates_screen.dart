import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'updates_controller.dart';
import 'updater.dart';

/// Update screen: current state card + check-now action + install handoff.
/// Install itself is the platform installer (FileProvider intent on Android,
/// Explorer on Windows) launched from the asset URL.
class UpdatesScreen extends ConsumerWidget {
  const UpdatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UpdateState state = ref.watch(updateControllerProvider);
    final ThemeData theme = Theme.of(context);
    final AppLocalizations? l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Updates', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            switch (state) {
              UpdateIdle(:final lastCheckedAt) => _MessageCard(
                icon: Icons.schedule,
                text:
                    lastCheckedAt?.toIso8601String() ??
                    (l10n?.updatesIdle ?? 'No check yet.'),
              ),
              UpdateChecking() => const Center(
                child: Padding(
                  padding: EdgeInsetsDirectional.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              UpdateAvailable(:final info) => _UpdateCard(info: info),
              UpdateUpToDate(:final localVersion) => _MessageCard(
                icon: Icons.check_circle,
                text:
                    l10n?.updatesUpToDate(localVersion) ??
                    'Up to date (v$localVersion)',
              ),
              UpdateFailed(:final message) => _MessageCard(
                icon: Icons.error_outline,
                text: message,
              ),
            },
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    ref.read(updateControllerProvider.notifier).checkNow(),
                icon: const Icon(Icons.refresh),
                label: Text(l10n?.updatesCheckNow ?? 'Check now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.info});

  final UpdateInfo info;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.system_update),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Update v${info.version} for ${info.platformKey}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (info.changelog.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                info.changelog,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _install(context),
              child: const Text('Download & install'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _install(BuildContext context) async {
    try {
      if (Platform.isAndroid) {
        // FileProvider ACTION_VIEW intent is the Play-safe install path;
        // the platform service lands with the release todo.
        await const MethodChannel(
          'vpn_service',
        ).invokeMethod<void>('installUpdate', {'url': info.assetUrl});
      } else if (Platform.isWindows) {
        await Process.start('explorer', <String>[info.assetUrl]);
      } else {
        throw UnsupportedError('no installer for ${Platform.operatingSystem}');
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(leading: Icon(icon), title: Text(text)),
    );
  }
}
