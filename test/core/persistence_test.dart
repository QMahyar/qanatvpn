import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/core/persistence/atomic_write.dart';
import 'package:yourvpn/core/persistence/debounced_saver.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yourvpn-persist');
  });

  tearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  group('atomicWriteString', () {
    test('content exact, no tmp leftovers', () async {
      final file = File('${dir.path}/rules.json');
      await atomicWriteString(file, '{"rules":[]}');

      expect(file.readAsStringSync(), '{"rules":[]}');
      expect(dir.listSync().where((e) => e.path.endsWith('.tmp')), isEmpty);
    });

    test('overwrite leaves single complete file', () async {
      final file = File('${dir.path}/policy.json');
      await atomicWriteString(file, 'v1');
      await atomicWriteString(file, 'v2');

      expect(file.readAsStringSync(), 'v2');
      expect(dir.listSync(), hasLength(1));
    });
  });

  group('DebouncedSaver', () {
    test('5 rapid schedules coalesce into 1 execution', () async {
      final saver = DebouncedSaver(delay: const Duration(milliseconds: 20));
      addTearDown(saver.dispose);
      var runs = 0;
      for (var i = 0; i < 5; i++) {
        saver.schedule(() async => runs++);
      }
      expect(saver.hasPending, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(runs, 1);
      expect(saver.hasPending, isFalse);
    });

    test('flush runs pending work immediately', () async {
      final saver = DebouncedSaver(delay: const Duration(seconds: 30));
      addTearDown(saver.dispose);
      var runs = 0;
      saver.schedule(() async => runs++);
      await saver.flush();

      expect(runs, 1);
      expect(saver.hasPending, isFalse);
    });

    test('dispose drops pending work', () async {
      final saver = DebouncedSaver(delay: const Duration(milliseconds: 10));
      var runs = 0;
      saver.schedule(() async => runs++);
      saver.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(runs, 0);
    });
  });
}
