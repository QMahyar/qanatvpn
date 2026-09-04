import 'dart:async';

/// Coalesces rapid `schedule()` calls into one trailing disk write.
///
/// Controllers update in-memory `state` immediately (UI stays responsive)
/// and schedule only the file write. Five keystrokes in 300ms → one write,
/// not five. `flush()` runs pending work now (tests, dispose paths).
class DebouncedSaver {
  DebouncedSaver({this.delay = const Duration(milliseconds: 300)});

  final Duration delay;

  Timer? _timer;
  Future<void> Function()? _pending;
  bool _disposed = false;

  /// Queue [work], replacing any not-yet-run write. The latest closure wins,
  /// so callers must capture the full next state (not a delta).
  void schedule(Future<void> Function() work) {
    if (_disposed) {
      return;
    }
    _pending = work;
    _timer?.cancel();
    _timer = Timer(delay, () {
      final run = _pending;
      _pending = null;
      _timer = null;
      if (run != null) {
        // Fire and forget: a failed disk write must not crash the UI.
        // ignore: discarded_futures
        run();
      }
    });
  }

  /// Number of writes still waiting on the timer (tests).
  bool get hasPending => _pending != null;

  /// Run pending work now instead of waiting for the timer.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    final run = _pending;
    _pending = null;
    if (run != null) {
      await run();
    }
  }

  /// Drop pending work and stop the timer (provider dispose).
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }
}
