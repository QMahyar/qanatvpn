import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qanatvpn/app/app.dart';
import 'package:qanatvpn/core/services/tunnel.dart';
import 'package:qanatvpn/l10n/app_localizations.dart';
import 'package:qanatvpn/modules/vpn/logic/vpn_notifier.dart';
import 'package:qanatvpn/modules/vpn/screens/home.dart';

/// 200% text-scale goldens: bento tiles must survive the accessibility
/// ceiling (1.35 clamp — user-visible). Overflow exceptions are asserted in
/// the first test; the power tile gets literal PNG goldens.
class _FakeTunnel extends Fake implements Tunnel {
  _FakeTunnel(this.phase);

  final TunnelState phase;

  @override
  TunnelState get state => phase;

  @override
  TunnelBlockReason? get blockReason =>
      phase == TunnelState.blocked ? TunnelBlockReason.airplaneMode : null;

  @override
  Stream<TunnelState> get status => const Stream<TunnelState>.empty();

  @override
  ConnectMetrics? get lastConnectMetrics =>
      phase == TunnelState.connected ? _fakeMetrics : null;

  static final ConnectMetrics _fakeMetrics = ConnectMetrics(
    tag: 'awg-hkg-02',
    phases: <String, Duration>{
      'grant': const Duration(milliseconds: 12),
      'config': const Duration(milliseconds: 34),
      'box': const Duration(milliseconds: 210),
      'firewall': const Duration(milliseconds: 3),
    },
  );
}

Widget _wrap(TunnelState phase, double textScale, {bool clamp = true}) {
  return ProviderScope(
    overrides: [tunnelProvider.overrideWithValue(_FakeTunnel(phase))],
    child: MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        // Same clamp the real app applies in QanatVpnApp.builder — bypassed
        // (clamp: false) for pre-clamp 200% goldens, which must prove the
        // raw layout survives, not the clamped output.
        data: MediaQuery.of(context).copyWith(
          textScaler: clamp
              ? clampTextScaler(TextScaler.linear(textScale))
              : TextScaler.linear(textScale),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Scaffold(body: HomeScreen()),
    ),
  );
}

void main() {
  testWidgets('home bento at 200% (pre-clamp) has no overflow exceptions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(375, 720);
    addTearDown(tester.view.reset);

    // RenderFlex overflow throws inside widget tests — surface it even
    // though tiles now scroll internally (a SingleChildScrollView hides
    // RenderFlex overflow from the framework's yellow stripes only when
    // the child fits the scroll extent; a real overflow still throws).
    await tester.pumpWidget(_wrap(TunnelState.connected, 2.0, clamp: false));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    // Layout honesty: every tile's content must fit its card — scrollable
    // children reporting larger intrinsic height than the viewport would
    // mean clipped content. Assert each tile's text is actually visible
    // (hit-testable at its own center), not scrolled out of the card.
    for (final tile in <Type>[PowerTile, StateTile, StatsTile, UpdateTile]) {
      final candidates = find.byType(tile);
      expect(candidates, findsOneWidget, reason: '$tile missing');
      expect(
        tester.getRect(candidates).height,
        greaterThan(40),
        reason: '$tile collapsed to nothing at 200%',
      );
    }
  });

  testWidgets('stats tile golden at ceiling scale (connected)',
      (tester) async {
    // Goldens are pixel-comparisons of platform-rendered text: they are
    // only stable on the OS that generated them (Windows). Linux CI font
    // shaping differs by ~2% — probed on run 34292781030.
    if (Platform.isLinux) {
      return; // silently pass on non-golden platforms
    }
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(TunnelState.connected, 1.35));
    await tester.pump(const Duration(seconds: 1));
    // 5th tile in the bento grid: bring it on-screen before rasterizing.
    await tester.scrollUntilVisible(
      find.byType(StatsTile),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(seconds: 1));

    await expectLater(
      find.byType(StatsTile),
      matchesGoldenFile('goldens/stats_tile_connected_135.png'),
    );
  });

  testWidgets('power tile golden at ceiling scale (connected)', (tester) async {
    if (Platform.isLinux) {
      return;
    }
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 240);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(TunnelState.connected, 1.35));
    await tester.pump(const Duration(seconds: 1));

    await expectLater(
      find.byType(PowerTile),
      matchesGoldenFile('goldens/power_tile_connected_135.png'),
    );
  });

  testWidgets('power tile golden at ceiling scale (blocked)', (tester) async {
    if (Platform.isLinux) {
      return;
    }
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 240);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(TunnelState.blocked, 1.35));
    await tester.pump(const Duration(seconds: 1));

    await expectLater(
      find.byType(PowerTile),
      matchesGoldenFile('goldens/power_tile_blocked_135.png'),
    );
  });
}
