import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/modules/health/diagnostics_controller.dart';
import 'package:yourvpn/modules/health/health.dart';

class _FakeHealth extends Fake implements Health {
  _FakeHealth(this.report);

  HealthReport report;
  bool shouldThrow = false;
  int snapshotCalls = 0;

  @override
  Future<HealthReport> snapshot() async {
    snapshotCalls += 1;
    if (shouldThrow) {
      throw StateError('probe died');
    }
    return report;
  }
}

void main() {
  testWidgets('controller snapshots immediately and refreshes', (tester) async {
    final fake = _FakeHealth(
      const HealthReport(score: 4, hijacked: true, pingMs: 30, stability: 100),
    );
    final container = ProviderContainer(
      overrides: [healthProvider.overrideWithValue(fake)],
    );

    // Build triggers the first tick.
    container.read(diagnosticsControllerProvider);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final state = container.read(diagnosticsControllerProvider);
    expect(state, isNotNull);
    expect(state!.score, 4);
    expect(state.pingMs, 30);
    expect(fake.snapshotCalls, greaterThanOrEqualTo(1));

    // Manual refresh bumps the call counter.
    final before = fake.snapshotCalls;
    await container.read(diagnosticsControllerProvider.notifier).refreshNow();
    expect(fake.snapshotCalls, greaterThan(before));

    // Dispose inside the test so onDispose cancels the periodic timer
    // before the framework's pending-timer invariant check.
    container.dispose();
  });

  testWidgets('probe failure keeps the last report on screen', (tester) async {
    final fake = _FakeHealth(
      const HealthReport(score: 6, hijacked: true, pingMs: 20, stability: 100),
    );
    final container = ProviderContainer(
      overrides: [healthProvider.overrideWithValue(fake)],
    );

    container.read(diagnosticsControllerProvider);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(container.read(diagnosticsControllerProvider)!.score, 6);

    // Next tick throws — the last report stays on screen.
    fake.shouldThrow = true;
    await tester.pump(const Duration(seconds: 10));

    final report = container.read(diagnosticsControllerProvider);
    expect(report, isNotNull);
    expect(report!.score, 6);

    container.dispose();
  });
}
