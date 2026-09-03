import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/app/app.dart';
import 'package:yourvpn/core/services/tunnel.dart';
import 'package:yourvpn/l10n/app_localizations.dart';
import 'package:yourvpn/modules/vpn/logic/vpn_notifier.dart';
import 'package:yourvpn/modules/vpn/screens/home.dart';

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
}

Widget _wrap(TunnelState phase, double textScale) {
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
        // Same clamp the real app applies in YourVpnApp.builder.
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: clampTextScaler(TextScaler.linear(textScale))),
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

    // RenderFlex overflow throws inside widget tests and fails the test
    // automatically — pumping is the whole assertion.
    await tester.pumpWidget(_wrap(TunnelState.connected, 2.0));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(PowerTile), findsOneWidget);
    expect(find.byType(UpdateTile), findsOneWidget);
  });

  testWidgets('power tile golden at ceiling scale (connected)', (tester) async {
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
