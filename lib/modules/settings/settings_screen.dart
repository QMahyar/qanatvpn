import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'settings_controller.dart';

/// Settings tab (audit W2.2 — no settings surface existed): theme, language,
/// auto-connect, auto-reconnect. Everything persists immediately.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Settings settings = ref.watch(settingsProvider);
    final SettingsController controller = ref.read(
      settingsProvider.notifier,
    );
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsetsDirectional.all(16),
        children: <Widget>[
          Text(
            l10n.settingsTitle,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.settingsAppearance,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.brightness_6),
                title: Text(l10n.settingsTheme),
                subtitle: Text(
                  switch (themeModeFromString(settings.themeMode)) {
                    AppThemeMode.light => l10n.settingsThemeLight,
                    AppThemeMode.dark => l10n.settingsThemeDark,
                    AppThemeMode.system => l10n.settingsThemeSystem,
                  },
                ),
                trailing: SegmentedButton<String>(
                  segments: <ButtonSegment<String>>[
                    ButtonSegment<String>(
                      value: 'system',
                      icon: const Icon(Icons.brightness_auto),
                      tooltip: l10n.settingsThemeSystem,
                    ),
                    ButtonSegment<String>(
                      value: 'light',
                      icon: const Icon(Icons.light_mode),
                      tooltip: l10n.settingsThemeLight,
                    ),
                    ButtonSegment<String>(
                      value: 'dark',
                      icon: const Icon(Icons.dark_mode),
                      tooltip: l10n.settingsThemeDark,
                    ),
                  ],
                  selected: <String>{settings.themeMode},
                  onSelectionChanged: (Set<String> selection) =>
                      controller.setThemeMode(
                        themeModeFromString(selection.first),
                      ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(l10n.settingsLanguage),
                subtitle: Text(
                  switch (languageFromString(settings.language)) {
                    AppLanguage.en => 'English',
                    AppLanguage.fa => '\u0641\u0627\u0631\u0633\u06cc',
                    AppLanguage.system => l10n.settingsLanguageSystem,
                  },
                ),
                trailing: SegmentedButton<String>(
                  segments: <ButtonSegment<String>>[
                    ButtonSegment<String>(
                      value: 'system',
                      tooltip: l10n.settingsLanguageSystem,
                      label: Text(l10n.settingsLanguageSystemShort),
                    ),
                    const ButtonSegment<String>(
                      value: 'en',
                      label: Text('EN'),
                    ),
                    const ButtonSegment<String>(
                      value: 'fa',
                      label: Text('FA'),
                    ),
                  ],
                  selected: <String>{settings.language},
                  onSelectionChanged: (Set<String> selection) =>
                      controller.setLanguage(
                        languageFromString(selection.first),
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: l10n.settingsConnection,
            children: <Widget>[
              SwitchListTile(
                secondary: const Icon(Icons.bolt),
                title: Text(l10n.settingsAutoConnect),
                subtitle: Text(l10n.settingsAutoConnectSub),
                value: settings.autoConnect,
                onChanged: (bool value) => controller.setAutoConnect(value),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.restart_alt),
                title: Text(l10n.settingsReconnect),
                subtitle: Text(l10n.settingsReconnectSub),
                value: settings.reconnectEnabled,
                onChanged: (bool value) =>
                    controller.setReconnectEnabled(value),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: 8,
          horizontal: 4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, top: 8),
              child: Text(title, style: theme.textTheme.labelLarge),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
