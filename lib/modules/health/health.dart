import 'dart:async';
import 'dart:io';

/// Health report score bands (0-6), Slipnet-style:
/// 0 dead → 6 fully healthy (DNS resolved through tunnel, ping stable).
enum HealthLevel { dead, dns, ping, stability, tunnel, full }

class HealthReport {
  const HealthReport({
    required this.score,
    required this.hijacked,
    required this.pingMs,
    required this.stability,
  });

  /// 0-6 composite score.
  final int score;
  final bool hijacked;
  final int? pingMs;
  final int stability;

  HealthLevel get level {
    // Bands: 0 dead, 1-2 dns, 3-4 ping, 5 stability, 6 full.
    const bands = <HealthLevel>[
      HealthLevel.dead,
      HealthLevel.dns,
      HealthLevel.dns,
      HealthLevel.ping,
      HealthLevel.ping,
      HealthLevel.stability,
      HealthLevel.full,
    ];
    return bands[score.clamp(0, 6)];
  }
}

/// Probes injected for tests.
abstract interface class DnsProber {
  /// Returns true when resolving [host] yields the tunnel's resolver
  /// (hijack active), false when the ISP resolver answers.
  Future<bool> isHijacked();
}

abstract interface class Pinger {
  /// TCP connect ping in ms, null on failure.
  Future<int?> ping(String host, int port);
}

/// Deep health module: one snapshot aggregates hijack + ping + stability
/// into a hierarchical 0-6 score (Logs→Ping→Stats per the UI LED).
class Health {
  Health({
    required DnsProber prober,
    required Pinger pingerAdapter,
    this.pingTarget = '1.1.1.1',
    this.pingPort = 443,
  }) : _dnsProber = prober,
       _pinger = pingerAdapter;

  final DnsProber _dnsProber;
  final Pinger _pinger;
  final String pingTarget;
  final int pingPort;

  static const int _maxSamples = 20;
  final List<bool> _pingResults = <bool>[];

  Future<HealthReport> snapshot() async {
    final bool hijacked = await _dnsProber.isHijacked();
    int score = 0;
    if (hijacked) {
      score = 2; // DNS through tunnel = base 2
    }
    final int? pingMs = await _pinger.ping(pingTarget, pingPort);
    final bool pingOk = pingMs != null && pingMs > 0;
    _pingResults.add(pingOk);
    if (_pingResults.length > _maxSamples) {
      _pingResults.removeAt(0);
    }
    if (pingOk) {
      score += 2; // +2 ping reachable
    }
    final int stability = _stabilityPercent();
    if (pingOk && _pingResults.length >= 2 && stability >= 80) {
      score += 2; // +2 stable over a meaningful window
    }
    return HealthReport(
      score: score.clamp(0, 6),
      hijacked: hijacked,
      pingMs: pingMs,
      stability: stability,
    );
  }

  int _stabilityPercent() {
    if (_pingResults.isEmpty) {
      return 0;
    }
    final ok = _pingResults.where((r) => r).length;
    return (ok * 100) ~/ _pingResults.length;
  }
}

/// Real prober: hijack detected when a wildcard DNS query resolves into the
/// FakeIP pool (198.18.0.0/15) — only the tunnel's FakeIP server does that.
class FakeIpDnsProber implements DnsProber {
  @override
  Future<bool> isHijacked() async {
    try {
      final List<InternetAddress> addresses =
          await InternetAddress.lookup('probe.yourvpn.internal')
              .timeout(const Duration(seconds: 3));
      return addresses.any(_inFakeIpPool);
    } on Object {
      return false;
    }
  }

  bool _inFakeIpPool(InternetAddress address) {
    final bytes = address.rawAddress;
    if (bytes.length != 4) {
      return false;
    }
    // 198.18.0.0/15 → 198.18.x.x - 198.19.x.x
    return bytes[0] == 198 && (bytes[1] == 18 || bytes[1] == 19);
  }
}

/// Real TCP-connect pinger.
class TcpPinger implements Pinger {
  const TcpPinger();

  @override
  Future<int?> ping(String host, int port) async {
    final Stopwatch watch = Stopwatch()..start();
    try {
      final Socket socket =
          await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      socket.destroy();
      return watch.elapsedMilliseconds;
    } on Object {
      return null;
    }
  }
}
