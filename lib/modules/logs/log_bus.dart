import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory engine log: ring buffer + broadcast stream. The box adapter
/// feeds it from `box_events` log lines; the Logs screen renders it.
class LogBus {
  LogBus({this.capacity = 500});

  final int capacity;

  final List<EngineLogLine> _buffer = <EngineLogLine>[];
  final StreamController<EngineLogLine> _controller =
      StreamController<EngineLogLine>.broadcast();

  Stream<EngineLogLine> get stream => _controller.stream;

  List<EngineLogLine> get lines => List<EngineLogLine>.unmodifiable(_buffer);

  void add(EngineLogLine line) {
    _buffer.add(line);
    if (_buffer.length > capacity) {
      _buffer.removeRange(0, _buffer.length - capacity);
    }
    _controller.add(line);
  }

  void clear() {
    _buffer.clear();
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

  static EngineLogLine parse(String raw) {
    final match = RegExp(
      r'^\[?(INFO|WARN|ERROR|FATAL|DEBUG|TRACE)\]?\s*(.*)$',
    ).firstMatch(raw);
    if (match != null) {
      return EngineLogLine(
        level: match.group(1)!,
        message: match.group(2)!.replaceFirst(RegExp(r'^\[\d+\]\s*'), ''),
      );
    }
    return EngineLogLine(level: '', message: raw);
  }
}

final logBusProvider = Provider<LogBus>((ref) => LogBus());

/// Live view-model for the Logs screen: replays the buffer, then appends.
class LogsController extends Notifier<List<EngineLogLine>> {
  @override
  List<EngineLogLine> build() {
    final bus = ref.watch(logBusProvider);
    final sub = bus.stream.listen((line) {
      if (line.isClearedMarker) {
        state = const <EngineLogLine>[];
        return;
      }
      state = <EngineLogLine>[...state, line];
      if (state.length > 500) {
        state = state.sublist(state.length - 500);
      }
    });
    ref.onDispose(sub.cancel);
    return bus.lines;
  }

  void clear() => ref.read(logBusProvider).clear();
}

final logsControllerProvider =
    NotifierProvider<LogsController, List<EngineLogLine>>(LogsController.new);
