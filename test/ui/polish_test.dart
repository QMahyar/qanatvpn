import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qanatvpn/app/app.dart';
import 'package:qanatvpn/core/services/tunnel.dart';
import 'package:qanatvpn/l10n/app_localizations.dart';
import 'package:qanatvpn/modules/vpn/logic/tunnel_l10n.dart';

AppLocalizations makeL10n(Locale locale) {
  return lookupAppLocalizations(locale);
}

void main() {
  group('clampTextScaler', () {
    double clamped(double scale) =>
        clampTextScaler(TextScaler.linear(scale)).scale(10);

    test('no-op inside the accessibility window', () {
      expect(clamped(1.0), 10.0);
      expect(clamped(1.2), 12.0);
      expect(clamped(0.9), 9.0);
      expect(clamped(1.35), 13.5);
    });

    test('clamps below 0.9 and above 1.35', () {
      expect(clamped(0.5), 9.0);
      expect(clamped(3.0), 13.5);
      expect(clamped(2.0), 13.5);
    });
  });

  group('TunnelStateL10n', () {
    test('every state maps to a non-enum English string', () {
      final l = makeL10n(const Locale('en'));
      final labels = TunnelState.values.map((s) => s.label(l)).toList();

      // Raw enum names never leak through.
      for (final state in TunnelState.values) {
        expect(labels, isNot(contains(state.name)));
      }
      expect(labels.toSet().length, TunnelState.values.length);
    });

    test('every block reason maps to a distinct human string', () {
      final l = makeL10n(const Locale('en'));
      final labels = TunnelBlockReason.values.map((r) => r.label(l)).toList();

      for (final reason in TunnelBlockReason.values) {
        expect(labels, isNot(contains(reason.name)));
      }
      expect(labels.toSet().length, TunnelBlockReason.values.length);
    });

    test('FA strings are Persian, not the EN fallback', () {
      final l = makeL10n(const Locale('fa'));
      expect(TunnelState.connected.label(l), 'متصل');
      expect(TunnelBlockReason.airplaneMode.label(l), 'حالت هواپیما روشن است');
    });
  });
}
