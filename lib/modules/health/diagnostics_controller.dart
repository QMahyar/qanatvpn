import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'health.dart';

final healthProvider = Provider<Health>(
  (ref) => Health(prober: FakeIpDnsProber(), pingerAdapter: const TcpPinger()),
);

/// Auto-refreshing health snapshot. Runs on a timer only while listened to
/// (autoDispose); each tick is one probe round (hijack + TCP ping).
class DiagnosticsController extends Notifier<HealthReport?> {
  Timer? _timer;

  @override
  HealthReport? build() {
    ref.onDispose(_stop);
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _tick());
    return null;
  }

  Future<void> _tick() async {
    try {
      state = await ref.read(healthProvider).snapshot();
    } on Object {
      // Probe failure leaves the last report on screen; next tick retries.
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refreshNow() => _tick();
}

final diagnosticsControllerProvider =
    NotifierProvider<DiagnosticsController, HealthReport?>(
      DiagnosticsController.new,
    );
