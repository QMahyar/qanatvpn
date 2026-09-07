import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory engine log: ring buffer + broadcast stream. The box adapter
/// feeds it from `box_events` log lines; the Logs screen renders it.
///
/// Flood-hardened: messages truncate at [maxLineLength], runs of identical
/// lines collapse into one `‹repeated N times›` summary, and the buffer
/// drops oldest past [capacity] (default 2000 — an engine spewing errors
/// must not OOM the app).
class LogBus {
  LogBus({this.capacity = 2000, this.maxLineLength = 4096});

  final int capacity;
  final int maxLineLength;

  final List<EngineLogLine> _buffer = <EngineLogLine>[];
  final StreamController<EngineLogLine> _controller =
      StreamController<EngineLogLine>.broadcast();

  String? _lastMessage;
  String _lastLevel = '';
  int _repeatCount = 0;

  /// Consecutive duplicates collapsed so far (diagnostics, tests).
  int droppedRepeats = 0;

  /// Redactions applied so far (diagnostics, tests) — audit W3.2.
  int redactions = 0;

  Stream<EngineLogLine> get stream => _controller.stream;

  List<EngineLogLine> get lines => List<EngineLogLine>.unmodifiable(_buffer);

  /// Strips secret-shaped material from engine lines before they enter the
  /// buffer (audit W3.2: a misconfigured WG/AWG endpoint FATAL echoes the
  /// private key in hex, forwarded verbatim to the on-screen log).
  ///
  /// Patterns, in order:
  /// 1. JSON/flag fields whose name carries key/password/secret/psk/token —
  ///    the value is replaced regardless of encoding;
  /// 2. standalone WG key shapes (44-char base64 with trailing `=`, 64-hex).
  static final List<RegExp> _secretPatterns = <RegExp>[
    // Tolerates JSON quoting around the separator (key":"value) and the
    // value (key": "value) as well as flag style (key=value).
    RegExp(
      r'([A-Za-z0-9_\-]*(?:private[_-]?key|password|secret|psk|token)'
      r'[A-Za-z0-9_\-]*"?\s*[:=]\s*"?)[A-Za-z0-9+/=_\-]{8,}',
      caseSensitive: false,
    ),
    RegExp(r'[A-Za-z0-9+/]{42,43}='),
    RegExp(r'\b[0-9a-fA-F]{64}\b'),
  ];

  static const String _redactedMarker = '[REDACTED]';

  String _redactSecrets(String message) {
    var out = message;
    for (final pattern in _secretPatterns) {
      out = out.replaceAllMapped(pattern, (Match m) {
        final prefix = m.groupCount >= 1 ? (m.group(1) ?? '') : '';
        return '$prefix$_redactedMarker';
      });
    }
    if (out != message) {
      redactions++;
    }
    return out;
  }

  void add(EngineLogLine line) {
    var message = _redactSecrets(line.message);
    if (message.length > maxLineLength) {
      message = message.substring(0, maxLineLength);
    }
    if (message == _lastMessage && line.level == _lastLevel) {
      _repeatCount++;
      droppedRepeats++;
      return;
    }
    _flushRepeats();
    _lastMessage = message;
    _lastLevel = line.level;
    _repeatCount = 1;
    _emit(EngineLogLine(level: line.level, message: message));
  }

  void _flushRepeats() {
    if (_repeatCount >= 3 && _lastMessage != null) {
      _emit(
        EngineLogLine(level: '', message: '‹repeated $_repeatCount times›'),
      );
    }
    _repeatCount = 0;
  }

  void _emit(EngineLogLine line) {
    _buffer.add(line);
    if (_buffer.length > capacity) {
      _buffer.removeRange(0, _buffer.length - capacity);
    }
    _controller.add(line);
  }

  void clear() {
    _buffer.clear();
    _lastMessage = null;
    _lastLevel = '';
    _repeatCount = 0;
    _controller.add(const EngineLogLine(level: '', message: '__cleared__'));
  }
}

class EngineLogLine {
  const EngineLogLine({required this.level, required this.message});

  /// Parsed from the sing-box log prefix (`INFO`, `WARN`, `ERROR`, `FATAL`,
  /// `DEBUG`) when present; empty for control markers.
  final String level;
  final String message;

  bool get isClearedMarker => message == '__cleared__';

  bool get isError => level == 'ERROR' || level == 'FATAL';

  static final RegExp _levelPrefix = RegExp(
    r'^\[?(INFO|WARN|ERROR|FATAL|DEBUG|TRACE)\]?\s*(.*)$',
  );
  static final RegExp _tickPrefix = RegExp(r'^\[\d+\]\s*');

  static EngineLogLine parse(String raw) {
    final match = _levelPrefix.firstMatch(raw);
    if (match != null) {
      return EngineLogLine(
        level: match.group(1)!,
        message: match.group(2)!.replaceFirst(_tickPrefix, ''),
      );
    }
    return EngineLogLine(level: '', message: raw);
  }
}

final logBusProvider = Provider<LogBus>((ref) => LogBus());

/// Live view-model for the Logs screen: replays the buffer, then appends.
///
/// UI rebuilds batch on a 250ms window — an engine flood otherwise rebuilds
/// the list per line (O(n) copy + widget rebuild each). The buffer itself is
/// lossless; only the *rendered* state lags by one window.
class LogsController extends Notifier<List<EngineLogLine>> {
  /// Batch window for UI appends. Short enough to feel live, long enough to
  /// coalesce floods into one rebuild.
  static const batchWindow = Duration(milliseconds: 250);

  final List<EngineLogLine> _pending = <EngineLogLine>[];
  Timer? _flushTimer;
  StreamSubscription<EngineLogLine>? _sub;

  @override
  List<EngineLogLine> build() {
    final bus = ref.watch(logBusProvider);
    _sub?.cancel();
    _sub = bus.stream.listen(_onLine);
    ref.onDispose(() {
      _flushTimer?.cancel();
      _flushTimer = null;
      _sub?.cancel();
      _sub = null;
    });
    return bus.lines;
  }

  void _onLine(EngineLogLine line) {
    if (line.isClearedMarker) {
      _pending.clear();
      _flushTimer?.cancel();
      _flushTimer = null;
      state = const <EngineLogLine>[];
      return;
    }
    _pending.add(line);
    _flushTimer ??= Timer(batchWindow, _flush);
  }

  void _flush() {
    _flushTimer = null;
    if (_pending.isEmpty) {
      return;
    }
    final bus = ref.read(logBusProvider);
    // Re-read the buffer instead of appending: the bus already applied caps
    // and repeat-collapsing, so the view mirrors it exactly.
    state = List<EngineLogLine>.unmodifiable(
      bus.lines.length > bus.capacity
          ? bus.lines.sublist(bus.lines.length - bus.capacity)
          : bus.lines,
    );
    _pending.clear();
  }

  void clear() => ref.read(logBusProvider).clear();
}

final logsControllerProvider =
    NotifierProvider<LogsController, List<EngineLogLine>>(LogsController.new);
