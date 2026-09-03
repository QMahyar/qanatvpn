import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/core/startup/app_startup.dart';

void main() {
  group('PhaseTimer', () {
    test('records two phases with non-negative durations', () async {
      final timer = PhaseTimer();

      await timer.timed('a', () async {});
      await timer.timed(
        'b',
        () async => Future<void>.delayed(const Duration(milliseconds: 1)),
      );

      expect(timer.phases.keys, containsAll(<String>['a', 'b']));
      expect(timer.phases['a']! >= Duration.zero, isTrue);
      expect(timer.phases['b']! >= Duration.zero, isTrue);
    });

    test('report snapshots phases and total', () async {
      final timer = PhaseTimer();
      await timer.timed('work', () async {});

      final report = timer.report(const Duration(milliseconds: 5));

      expect(report.phases.keys, contains('work'));
      expect(report.total, const Duration(milliseconds: 5));
      expect(report.phases['work']! >= Duration.zero, isTrue);
    });

    test('records phase even when work throws', () async {
      final timer = PhaseTimer();

      await expectLater(
        timer.timed<void>('boom', () async => throw StateError('x')),
        throwsStateError,
      );

      expect(timer.phases.keys, contains('boom'));
      expect(timer.phases['boom']! >= Duration.zero, isTrue);
    });
  });
}
