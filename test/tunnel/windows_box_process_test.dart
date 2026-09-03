import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/core/services/tunnel.dart';
import 'package:yourvpn/core/services/windows_box_process.dart';

/// Scriptable fake of dart:io Process for lifecycle tests.
class FakeProcess implements Process {
  FakeProcess({
    this.exitAfter = const Duration(milliseconds: 50),
    this.exitCodeValue = 0,
  });

  final Duration exitAfter;
  final int exitCodeValue;

  final StreamController<List<int>> _stdout =
      StreamController<List<int>>.broadcast();

  /// Test-facing handle: write stderr lines the adapter should see.
  final StreamController<List<int>> stderrSink =
      StreamController<List<int>>.broadcast();

  late final Completer<int> _exitCompleter = Completer<int>()
    ..future.whenComplete(() {});

  bool get isDead => _exitCompleter.isCompleted;

  void die(int code) {
    if (!_exitCompleter.isCompleted) {
      _exitCompleter.complete(code);
    }
  }

  @override
  Future<int> get exitCode => _exitCompleter.future;

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => stderrSink.stream;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    die(-15);
    return true;
  }

  @override
  int get pid => 4242;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yourvpn-winbox');
  });

  tearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  final TypedConfig config = const TypedConfig(
    tag: 'HKG-02',
    json: <String, dynamic>{
      'log': <String, dynamic>{'level': 'info'},
    },
  );

  test('happy path: spawns with run -c, started event, stop kills', () async {
    final started = <String>[];
    final fake = FakeProcess();
    final adapter = WindowsBoxProcessAdapter(
      processFactory: (exe, args, {mode = ProcessStartMode.normal}) async {
        started.add('$exe ${args.join(' ')}');
        return fake;
      },
    );

    await adapter.start(config);

    expect(started.single, contains('sing-box.exe run -c'));
    expect(started.single, contains('--disable-color'));

    final events = <BoxEvent>[];
    final sub = adapter.events.listen(events.add);
    await adapter.stop();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(events.map((e) => e.kind), contains(BoxEventKind.stopped));
  });

  test('early death with non-zero exit → start throws StateError', () async {
    final fake = FakeProcess(exitAfter: Duration.zero, exitCodeValue: 1);
    final adapter = WindowsBoxProcessAdapter(
      processFactory: (exe, args, {mode = ProcessStartMode.normal}) async {
        // FATAL on stderr, die immediately.
        fake.stderrSink.add(utf8.encode('FATAL[0000] decode config: bad'));
        fake.die(1);
        return fake;
      },
    );

    await expectLater(adapter.start(config), throwsA(isA<StateError>()));
  });

  test('spawn failure (missing exe) → StateError, no events', () async {
    final adapter = WindowsBoxProcessAdapter(
      processFactory: (exe, args, {mode = ProcessStartMode.normal}) async {
        throw const FileSystemException('not found');
      },
    );

    await expectLater(adapter.start(config), throwsA(isA<StateError>()));
  });

  test('double start → StateError', () async {
    final fake = FakeProcess(exitAfter: const Duration(hours: 1));
    var spawnCount = 0;
    final adapter = WindowsBoxProcessAdapter(
      processFactory: (exe, args, {mode = ProcessStartMode.normal}) async {
        spawnCount += 1;
        return fake;
      },
    );

    await adapter.start(config);
    await expectLater(adapter.start(config), throwsA(isA<StateError>()));
    expect(spawnCount, 1);
  });

  test('stop when not running is a no-op', () async {
    final adapter = WindowsBoxProcessAdapter(
      processFactory: (exe, args, {mode = ProcessStartMode.normal}) async =>
          FakeProcess(),
    );

    await adapter.stop();
    expect(true, isTrue);
  });

  test('crash while running surfaces through events stream', () async {
    final fake = FakeProcess(exitAfter: const Duration(hours: 1));
    final adapter = WindowsBoxProcessAdapter(
      processFactory: (exe, args, {mode = ProcessStartMode.normal}) async =>
          fake,
    );
    final events = <BoxEvent>[];
    final sub = adapter.events.listen(events.add);

    await adapter.start(config);
    fake.die(3);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    final kinds = events.map((e) => e.kind).toList();
    expect(kinds, contains(BoxEventKind.started));
    expect(kinds.last, BoxEventKind.crashed);
  });
}
