import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/modules/logs/log_bus.dart';

void main() {
  group('LogBus flood caps', () {
    test('messages truncate at maxLineLength', () {
      final bus = LogBus(maxLineLength: 16);
      bus.add(EngineLogLine(level: 'INFO', message: 'x' * 100));

      expect(bus.lines.single.message, 'x' * 16);
    });

    test('runs of identical lines collapse into a repeat summary', () {
      final bus = LogBus();
      for (var i = 0; i < 5; i++) {
        bus.add(const EngineLogLine(level: 'INFO', message: 'same'));
      }
      bus.add(const EngineLogLine(level: 'INFO', message: 'different'));

      final messages = bus.lines.map((l) => l.message).toList();
      expect(messages, <String>[
        'same',
        '‹repeated 5 times›',
        'different',
      ]);
      expect(bus.droppedRepeats, 4);
    });

    test('short runs (under 3) emit no summary', () {
      final bus = LogBus();
      bus.add(const EngineLogLine(level: 'INFO', message: 'a'));
      bus.add(const EngineLogLine(level: 'INFO', message: 'a'));
      bus.add(const EngineLogLine(level: 'INFO', message: 'b'));

      expect(
        bus.lines.map((l) => l.message).toList(),
        <String>['a', 'b'],
      );
    });

    test('same text at different levels does not collapse', () {
      final bus = LogBus();
      bus.add(const EngineLogLine(level: 'INFO', message: 'x'));
      bus.add(const EngineLogLine(level: 'ERROR', message: 'x'));

      expect(bus.lines, hasLength(2));
      expect(bus.droppedRepeats, 0);
    });

    test('buffer drops oldest past capacity', () {
      final bus = LogBus(capacity: 3);
      for (var i = 0; i < 5; i++) {
        bus.add(EngineLogLine(level: 'INFO', message: 'line $i'));
      }

      expect(bus.lines.map((l) => l.message).toList(), <String>[
        'line 2',
        'line 3',
        'line 4',
      ]);
    });

    test('clear resets repeat tracking', () {
      final bus = LogBus();
      bus.add(const EngineLogLine(level: 'INFO', message: 'same'));
      bus.add(const EngineLogLine(level: 'INFO', message: 'same'));
      bus.clear();
      bus.add(const EngineLogLine(level: 'INFO', message: 'same'));

      expect(bus.lines.map((l) => l.message).toList(), <String>['same']);
    });
  });

  group('LogsController batching', () {
    test('rapid lines coalesce into one state update', () async {
      final bus = LogBus();
      final container = ProviderContainer(
        overrides: [logBusProvider.overrideWithValue(bus)],
      );
      addTearDown(container.dispose);

      expect(container.read(logsControllerProvider), isEmpty);
      for (var i = 0; i < 5; i++) {
        bus.add(EngineLogLine(level: 'INFO', message: 'line $i'));
      }
      // Still batched — nothing rendered yet.
      expect(container.read(logsControllerProvider), isEmpty);

      await Future<void>.delayed(
        LogsController.batchWindow + const Duration(milliseconds: 100),
      );
      expect(
        container.read(logsControllerProvider).map((l) => l.message),
        <String>['line 0', 'line 1', 'line 2', 'line 3', 'line 4'],
      );
    });

    test('clear marker applies immediately, pending batch dropped', () async {
      final bus = LogBus();
      final container = ProviderContainer(
        overrides: [logBusProvider.overrideWithValue(bus)],
      );
      addTearDown(container.dispose);

      container.read(logsControllerProvider);
      bus.add(const EngineLogLine(level: 'INFO', message: 'pending'));
      bus.clear();

      expect(container.read(logsControllerProvider), isEmpty);
      await Future<void>.delayed(
        LogsController.batchWindow + const Duration(milliseconds: 100),
      );
      expect(container.read(logsControllerProvider), isEmpty);
    });

    test('replays existing buffer on subscribe', () async {
      final bus = LogBus();
      bus.add(const EngineLogLine(level: 'INFO', message: 'before'));
      final container = ProviderContainer(
        overrides: [logBusProvider.overrideWithValue(bus)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(logsControllerProvider).map((l) => l.message),
        <String>['before'],
      );
    });
  });
}
