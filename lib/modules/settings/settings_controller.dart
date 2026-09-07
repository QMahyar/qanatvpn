import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_store.dart';

export 'settings_store.dart' show Settings, SettingsStore;

/// Global settings store provider — overridden in tests with a temp dir.
final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => const SettingsStore(),
);

/// Theme-mode enum bridging the persisted string to Material's enum.
enum AppThemeMode { system, light, dark }

AppThemeMode themeModeFromString(String value) => switch (value) {
  'light' => AppThemeMode.light,
  'dark' => AppThemeMode.dark,
  _ => AppThemeMode.system,
};

/// App language override: system follows the platform locale.
enum AppLanguage { system, en, fa }

AppLanguage languageFromString(String value) => switch (value) {
  'en' => AppLanguage.en,
  'fa' => AppLanguage.fa,
  _ => AppLanguage.system,
};

/// Loads persisted settings at startup and persists every change.
class SettingsController extends Notifier<Settings> {
  @override
  Settings build() => ref.watch(settingsStoreProvider).read();

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode.name);
    await ref.read(settingsStoreProvider).save(state);
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = state.copyWith(language: language.name);
    await ref.read(settingsStoreProvider).save(state);
  }

  Future<void> setAutoConnect(bool value) async {
    state = state.copyWith(autoConnect: value);
    await ref.read(settingsStoreProvider).save(state);
  }

  Future<void> setReconnectEnabled(bool value) async {
    state = state.copyWith(reconnectEnabled: value);
    await ref.read(settingsStoreProvider).save(state);
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, Settings>(SettingsController.new);

/// Bridges [AppThemeMode] to MaterialApp's themeMode.
final effectiveThemeModeProvider = Provider<ThemeMode>((ref) {
  return switch (ref.watch(settingsProvider).themeMode) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
});

/// Bridges [AppLanguage] to MaterialApp's locale (null = system).
final effectiveLocaleProvider = Provider<Locale?>((ref) {
  return switch (ref.watch(settingsProvider).language) {
    'en' => const Locale('en'),
    'fa' => const Locale('fa'),
    _ => null,
  };
});
