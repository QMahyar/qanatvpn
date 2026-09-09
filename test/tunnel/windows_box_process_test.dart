import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qanatvpn/core/services/tunnel.dart';
import 'package:qanatvpn/core/services/windows_box_process.dart';

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
    dir = await Directory.systemTemp.createTemp('qanatvpn-winbox');
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

  group('exe resolution (audit W1.3: CI bundles at bundle root)', () {
    // The resolver's probe semantics are Windows-path specific: an absolute
    // configured path is returned verbatim, drive-relative fallbacks differ
    // on POSIX (probe 34308592013: '/tmp/...C:/tools/box/sing-box.exe').
    if (!Platform.isWindows) {
      return; // group body never registers off-Windows
    }
    test('release layout: <bundle>/sing-box.exe wins when dev path missing', () {
      // Bundle contains ONLY the root exe (CI zip layout). The configured
      // dev path must fall through to the bundle-root candidate.
      File('${dir.path}${Platform.pathSeparator}sing-box.exe')
          .writeAsStringSync('mz');
      final resolved = resolveWindowsExe('windows/sing-box.exe', dir.path);
      expect(resolved, '${dir.path}${Platform.pathSeparator}sing-box.exe');
    });

    test('dev layout: <bundle>/windows/sing-box.exe wins when present', () {
      final nested = Directory(
        '${dir.path}${Platform.pathSeparator}windows',
      )..createSync();
      File(
        '${nested.path}${Platform.pathSeparator}sing-box.exe',
      ).writeAsStringSync('mz');
      final resolved = resolveWindowsExe('windows/sing-box.exe', dir.path);
      expect(
        resolved,
        '${nested.path}${Platform.pathSeparator}sing-box.exe',
      );
    });

    test('absolute configured path used verbatim', () {
      final resolved = resolveWindowsExe('C:/tools/box/sing-box.exe', dir.path);
      expect(resolved, 'C:/tools/box/sing-box.exe');
    });

    test('neither layout present: dev-layout candidate returned (diagnosable)', () {
      final resolved = resolveWindowsExe(
        'windows/definitely-missing.exe',
        dir.path,
      );
      expect(resolved, contains('definitely-missing.exe'));
    });

    test('dev layout preferred when BOTH exist (config wins)', () {
      final nested = Directory(
        '${dir.path}${Platform.pathSeparator}windows',
      )..createSync();
      File(
        '${nested.path}${Platform.pathSeparator}sing-box.exe',
      ).writeAsStringSync('mz');
      File('${dir.path}${Platform.pathSeparator}sing-box.exe')
          .writeAsStringSync('mz');
      final resolved = resolveWindowsExe('windows/sing-box.exe', dir.path);
      expect(resolved, contains('${Platform.pathSeparator}windows'));
    });
  });
}
