import 'package:flutter_test/flutter_test.dart';
import 'package:qanatvpn/modules/logs/log_bus.dart';

void main() {
  group('EngineLogLine.parse', () {
    test('splits known level prefixes', () {
      final line = EngineLogLine.parse('INFO[0000] inbound/tun: started');
      expect(line.level, 'INFO');
      expect(line.message, 'inbound/tun: started');
      expect(line.isError, isFalse);
    });

    test('FATAL/ERROR flag as errors', () {
      expect(EngineLogLine.parse('FATAL decode config: bad').isError, isTrue);
      expect(EngineLogLine.parse('ERROR[0001] dial failed').isError, isTrue);
    });

    test('unknown prefix keeps the raw line', () {
      final line = EngineLogLine.parse('start engine at 2026-09-02');
      expect(line.level, isEmpty);
      expect(line.message, 'start engine at 2026-09-02');
    });
  });

  group('LogBus', () {
    test('buffer replays and caps at capacity', () {
      final bus = LogBus(capacity: 3);
      for (var i = 0; i < 5; i++) {
        bus.add(EngineLogLine.parse('INFO line $i'));
      }

      expect(bus.lines.map((l) => l.message).toList(), <String>[
        'line 2',
        'line 3',
        'line 4',
      ]);
    });

    test(
      'broadcasts to late listeners via buffer replay, live via stream',
      () async {
        final bus = LogBus();
        bus.add(EngineLogLine.parse('INFO first'));

        final seen = <EngineLogLine>[];
        final sub = bus.stream.listen(seen.add);
        await Future<void>.delayed(Duration.zero);

        bus.add(EngineLogLine.parse('ERROR second'));
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(seen.single.isError, isTrue);
        expect(bus.lines, hasLength(2));
      },
    );

    test('clear emits the marker and empties the buffer', () async {
      final bus = LogBus();
      bus.add(EngineLogLine.parse('INFO a'));
      bus.add(EngineLogLine.parse('INFO b'));

      final seen = <EngineLogLine>[];
      final sub = bus.stream.listen(seen.add);
      bus.clear();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(bus.lines, isEmpty);
      expect(seen.single.isClearedMarker, isTrue);
    });
  });
}
