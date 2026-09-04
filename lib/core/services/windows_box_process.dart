import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../modules/logs/log_bus.dart';
import 'tunnel.dart';

/// Windows engine: `sing-box.exe run -c <file>` subprocess.
///
/// The exe opens its own wintun TUN, so the platform adapter reports
/// `engineManagedTun=true` (same as Android's openTun path) and establish/
/// protect never run on Windows. This adapter only manages the process
/// lifecycle: write config to a temp file, spawn, watch exit. A non-zero
/// exit or early death surfaces as a crash event; stop uses taskkill.
class WindowsBoxProcessAdapter implements BoxAdapter {
  WindowsBoxProcessAdapter({
    this.executablePath = 'windows/sing-box.exe',
    this.workingDir,
    this.processFactory = Process.start,
    LogBus? logBus,
  }) : _logBus = logBus ?? LogBus();

  /// Absolute exe path: relative [executablePath] resolves against the
  /// running bundle directory (Platform.resolvedExecutable), so installed
  /// apps (CWD != bundle root) still spawn. Override stays test-relative.
  final ProcessFactory processFactory;

  final String executablePath;
  final String? workingDir;
  String get _resolvedExe {
    final direct = File(executablePath);
    if (direct.isAbsolute) {
      return executablePath;
    }
    try {
      final bundleDir = File(Platform.resolvedExecutable).parent.path;
      final sep = Platform.isWindows ? '\\' : '/';
      final rel = executablePath.replaceAll('/', sep);
      return '$bundleDir$sep$rel';
    } on Object {
      return executablePath;
    }
  }

  /// Both pipes feed the shared log bus (same caps as Android) so the Logs
  /// screen is not blind on Windows; previously stdout was discarded and
  /// only the last stderr line survived in memory.
  final LogBus _logBus;

  final StreamController<BoxEvent> _events =
      StreamController<BoxEvent>.broadcast();

  Process? _process;
  File? _configFile;
  StreamSubscription<String>? _stderrSub;
  StreamSubscription<String>? _stdoutSub;
  bool _stopping = false;

  @override
  Stream<BoxEvent> get events => _events.stream;

  @override
  Future<void> start(TypedConfig config) async {
    if (_process != null) {
      throw StateError('box process already running');
    }
    // Per-app split on Windows: the config file carries the tun route
    // policy, engine-level per-app filtering is Android-only (VpnService
    // builder). Documented: Windows split ships with the routing editor.
    final json = jsonEncode(config.json);
    final file = File(
      '${Directory.systemTemp.path}/yourvpn_box_${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(json);
    _configFile = file;

    Process process;
    try {
      process = await processFactory(_resolvedExe, <String>[
        'run',
        '-c',
        file.path,
        '--disable-color',
      ], mode: ProcessStartMode.normal);
    } on Object catch (error) {
      await _cleanupConfig();
      throw StateError('failed to spawn sing-box.exe: $error');
    }
    _process = process;
    _stopping = false;

    // Early-exit detection: config errors FATAL within the first seconds.
    _exitWait = process.exitCode.then<int>((code) {
      final wasStopping = _stopping;
      _process = null;
      _stderrSub?.cancel();
      _stdoutSub?.cancel();
      _stderrSub = null;
      _stdoutSub = null;
      _cleanupConfig();
      if (!wasStopping && code != 0) {
        _events.add(
          BoxEvent(BoxEventKind.crashed, StateError('sing-box exited $code')),
        );
      } else if (!wasStopping) {
        _events.add(const BoxEvent(BoxEventKind.stopped));
      }
      return code;
    });

    void feed(String line) {
      // Length caps + repeat collapsing live in LogBus now (shared with
      // the Android box_events path); keep only last-error tracking here.
      _logBus.add(EngineLogLine.parse(line));
      if (line.contains('FATAL') || line.contains('ERROR')) {
        _lastErrorLine = line;
      }
    }

    _stderrSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(feed);
    _stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(feed);

    // Give the process a beat to fail on bad config; a still-running
    // process at this point is considered started.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (await _hasExited()) {
      await _exitWait;
      throw StateError(_lastErrorLine ?? 'sing-box.exe exited during startup');
    }
    _events.add(const BoxEvent(BoxEventKind.started));
  }

  String? _lastErrorLine;
  Future<int>? _exitWait;

  Future<bool> _hasExited() async {
    final process = _process;
    if (process == null) {
      return true;
    }
    // exitCode doesn't expose completion without awaiting; poll a microtask
    // race against a zero timeout — if the process already died, the future
    // resolves on the next event turn.
    final result = await process.exitCode
        .timeout(Duration.zero, onTimeout: () => -1)
        .catchError((_) => -1);
    return result != -1;
  }

  @override
  Future<void> stop() async {
    final process = _process;
    if (process == null) {
      return;
    }
    _stopping = true;
    try {
      // Graceful first: taskkill without /F lets the signal handler run.
      final result = await Process.run('taskkill', <String>[
        '/PID',
        process.pid.toString(),
      ]);
      if (result.exitCode != 0) {
        await Process.run('taskkill', <String>[
          '/F',
          '/PID',
          process.pid.toString(),
        ]);
      }
    } on Object {
      // taskkill unavailable or process already gone.
    }
    // In-process backstop (covers embedded/test process doubles where
    // taskkill cannot see the fake PID).
    try {
      process.kill();
    } on Object {
      // Already dead.
    }
    // Never hang stop on a wedged process: force-continue after 5s.
    await _exitWait?.timeout(const Duration(seconds: 5), onTimeout: () => -1);
    _process = null;
    _stderrSub?.cancel();
    _stdoutSub?.cancel();
    _stderrSub = null;
    _stdoutSub = null;
    await _cleanupConfig();
    _events.add(const BoxEvent(BoxEventKind.stopped));
  }

  Future<void> _cleanupConfig() async {
    final file = _configFile;
    _configFile = null;
    if (file != null && file.existsSync()) {
      try {
        await file.delete();
      } on Object {
        // Temp file leak is acceptable; system temp cleans up.
      }
    }
  }
}

typedef ProcessFactory =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      ProcessStartMode mode,
    });
