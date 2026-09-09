import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qanatvpn/modules/logs/log_bus.dart';

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
      expect(messages, <String>['same', '‹repeated 5 times›', 'different']);
      expect(bus.droppedRepeats, 4);
    });

    test('short runs (under 3) emit no summary', () {
      final bus = LogBus();
      bus.add(const EngineLogLine(level: 'INFO', message: 'a'));
      bus.add(const EngineLogLine(level: 'INFO', message: 'a'));
      bus.add(const EngineLogLine(level: 'INFO', message: 'b'));

      expect(bus.lines.map((l) => l.message).toList(), <String>['a', 'b']);
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

  group('log secret redaction (W3.2)', () {
    test('JSON private_key field is redacted', () {
      final bus = LogBus();
      bus.add(
        EngineLogLine.parse(
          'FATAL[0000] decode config at endpoints[0]: '
          '{"private_key":"8B1a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5d6e7f8="}',
        ),
      );
      expect(bus.lines.last.message, contains('[REDACTED]'));
      expect(bus.lines.last.message, isNot(contains('8B1a2b3c')));
    });

    test('hex key after key: is redacted (sing-box FATAL echo)', () {
      final bus = LogBus();
      bus.add(
        EngineLogLine.parse(
          'FATAL: load private_key: 64hex'
          'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90',
        ),
      );
      expect(bus.lines.last.message, contains('[REDACTED]'));
      expect(
        bus.lines.last.message,
        isNot(contains('a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90')),
      );
    });

    test('standalone 44-char base64 WG key shape is redacted', () {
      final bus = LogBus();
      bus.add(
        EngineLogLine.parse(
          'WARN handshake failed peer-key=6Nrx0p1xVcBZ0kCjhSxJvL0p3a7cWQnPZ0n+qUeWc1E=',
        ),
      );
      expect(bus.lines.last.message, contains('[REDACTED]'));
      expect(bus.lines.last.message, isNot(contains('6Nrx0p1xVcBZ0kCjhSxJvL0p3a7cWQnPZ0n+qUeWc1E=')));
    });

    test('normal log lines pass through untouched', () {
      final bus = LogBus();
      bus.add(EngineLogLine.parse('INFO[0000] inbound/tun started at tun0'));
      bus.add(EngineLogLine.parse('INFO[0001] outbound/wireguard connected'));
      expect(bus.lines[0].message, 'inbound/tun started at tun0');
      expect(bus.lines[1].message, 'outbound/wireguard connected');
      expect(bus.redactions, 0);
    });
  });
}
