import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qanatvpn/l10n/app_localizations.dart';
import 'package:qanatvpn/modules/settings/settings_controller.dart';
import 'package:qanatvpn/modules/settings/settings_screen.dart';

Widget _wrap(Widget child, Directory dir) {
  return ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(
        SettingsStore(baseDir: dir.path),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

/// Audit W2.2: settings surface (theme, language, auto-connect,
/// reconnect) that persists immediately.
void main() {
  late Directory dir;
  late ProviderContainer container;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('qanatvpn-settings');
    container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(
          SettingsStore(baseDir: dir.path),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    // Windows holds the freshly-written file a beat longer; retry before
    // giving up. A leftover temp dir is harmless — never fail the test on
    // cleanup.
    for (var i = 0; i < 5; i++) {
      try {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
        break;
      } on Object {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  });

  test('defaults: system theme, system language, no auto-connect', () {
    final settings = container.read(settingsProvider);
    expect(settings.themeMode, 'system');
    expect(settings.language, 'system');
    expect(settings.autoConnect, isFalse);
    expect(settings.reconnectEnabled, isTrue);
  });

  test('every change persists to disk immediately', () async {
    final controller = container.read(settingsProvider.notifier);
    await controller.setThemeMode(AppThemeMode.dark);
    await controller.setLanguage(AppLanguage.fa);
    await controller.setAutoConnect(true);
    await controller.setReconnectEnabled(false);

    // Fresh store over the same dir (restart simulation).
    final reread = SettingsStore(baseDir: dir.path).read();
    expect(reread.themeMode, 'dark');
    expect(reread.language, 'fa');
    expect(reread.autoConnect, isTrue);
    expect(reread.reconnectEnabled, isFalse);
  });

  test('effective providers bridge to Material values', () async {
    final controller = container.read(settingsProvider.notifier);
    expect(container.read(effectiveThemeModeProvider), ThemeMode.system);
    expect(container.read(effectiveLocaleProvider), isNull);

    await controller.setThemeMode(AppThemeMode.light);
    await controller.setLanguage(AppLanguage.fa);
    expect(container.read(effectiveThemeModeProvider), ThemeMode.light);
    expect(container.read(effectiveLocaleProvider), const Locale('fa'));
  });

  testWidgets('settings screen renders and toggles persist', (tester) async {
    // Tall surface: the connection card sits below the fold at the default
    // 800x600 test size — everything visible, no scrolling games.
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const SettingsScreen(), dir));
    await tester.pumpAndSettle();

    // Two switch tiles: auto-connect off by default, reconnect on.
    final switches = tester.widgetList<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switches, hasLength(2));
    expect(switches.first.value, isFalse);
    expect(switches.last.value, isTrue);

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    // Assert through the widget tree's own ProviderScope (the setUp
    // container is a separate scope). Disk persistence is covered by the
    // unit tests above — inside fake-async the unawaited atomic write
    // cannot be awaited deterministically.
    final BuildContext screenContext = tester.element(
      find.byType(SettingsScreen),
    );
    final Settings state = ProviderScope.containerOf(
      screenContext,
    ).read(settingsProvider);
    expect(state.autoConnect, isTrue);
  });

  testWidgets('persisted settings survive a fresh screen build', (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Seed synchronously — awaiting the store's async save inside
    // fake-async never completes (real I/O on the real event loop).
    final seed = File('${dir.path}/settings.json');
    seed.parent.createSync(recursive: true);
    seed.writeAsStringSync(
      jsonEncode(
        const Settings(
          themeMode: 'dark',
          language: 'en',
          autoConnect: true,
        ).toJson(),
      ),
    );

    await tester.pumpWidget(_wrap(const SettingsScreen(), dir));
    await tester.pumpAndSettle();

    final switches = tester.widgetList<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switches.first.value, isTrue);
  });
}
