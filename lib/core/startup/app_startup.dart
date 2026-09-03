/// Startup timing helper: measures the pre-runApp critical path without
/// changing startup semantics (no lazy-init, no wiring changes).
///
/// Usage in `main()`:
/// ```dart
/// final total = Stopwatch()..start();
/// final timer = PhaseTimer();
/// final platform = await timer.timed('platformAdapter', () async => _platformAdapter());
/// total.stop();
/// latestStartupReport = StartupReport(total: total.elapsed, phases: timer.phases);
/// ```
library;

import 'dart:async';

/// Snapshot of one startup: wall-clock total plus per-phase durations.
class StartupReport {
  StartupReport({
    required this.total,
    required Map<String, Duration> phases,
  }) : phases = Map<String, Duration>.unmodifiable(phases);

  final Duration total;

  /// Phase name -> elapsed. Unmodifiable snapshot taken at report time.
  final Map<String, Duration> phases;
}

/// Most recent startup report, stashed by `main()` for diagnostics.
/// Null before `main()` finishes the pre-runApp work (e.g. in tests).
StartupReport? latestStartupReport;

/// Minimal Stopwatch wrapper: records each named phase into [phases].
class PhaseTimer {
  final Map<String, Duration> phases = <String, Duration>{};

  Future<T> timed<T>(String name, Future<T> Function() work) async {
    final sw = Stopwatch()..start();
    try {
      return await work();
    } finally {
      sw.stop();
      phases[name] = sw.elapsed;
    }
  }

  /// Builds an immutable [StartupReport] from the phases recorded so far.
  StartupReport report(Duration total) {
    return StartupReport(total: total, phases: phases);
  }
}
