import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../vpn/repositories/endpoints_controller.dart'
    show endpointStoreProvider;
import '../vpn/repositories/endpoint_store.dart' show StoredEndpoint;
import '../vpn/repositories/ingestion/normalized_endpoint.dart';

/// TCP connect prober seam — same shape as health's [Pinger], declared here
/// so the latency module does not import the health module (feature-first,
/// no cross-feature imports). Production adapter wraps Socket.connect.
abstract class LatencyPinger {
  /// TCP connect latency in ms, null on failure.
  Future<int?> ping(String host, int port);
}

class SocketLatencyPinger implements LatencyPinger {
  const SocketLatencyPinger();

  @override
  Future<int?> ping(String host, int port) async {
    final watch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(host, port);
      socket.destroy();
      return watch.elapsedMilliseconds;
    } on Object {
      return null;
    }
  }
}

/// Result of one sweep over endpoint addresses — kept as the typed return
/// of [measureAll] via its samples map; selection logic lives on
/// [LatencyState] (single source, no duplicate bestTag).
typedef LatencyReport = Map<String, int?>;

/// Sweep helper: measures every (address, port) pair concurrently with a
/// shared timeout. Never throws — unreachable hosts resolve to null.
Future<Map<String, int?>> measureAll(
  Map<String, ({String address, int port})> targets, {
  LatencyPinger pinger = const SocketLatencyPinger(),
  Duration timeout = const Duration(seconds: 4),
}) async {
  if (targets.isEmpty) {
    return const <String, int?>{};
  }
  final entries = await Future.wait(<Future<MapEntry<String, int?>>>[
    for (final entry in targets.entries)
      () async {
        final ms = await pinger
            .ping(entry.value.address, entry.value.port)
            .timeout(timeout, onTimeout: () => null);
        return MapEntry(entry.key, ms);
      }(),
  ]);
  return Map<String, int?>.fromEntries(entries);
}

/// (address, port) pair for one stored endpoint. WireGuard/AWG probes the
/// first peer's `host:port` endpoint string (bracketed IPv6 aware); proxy
/// protocols probe their server address directly. Null when the record
/// carries no probeable address.
({String address, int port})? endpointProbeTarget(StoredEndpoint stored) {
  final endpoint = stored.endpoint;
  return switch (endpoint) {
    WireGuardEndpoint() => _peerTarget(endpoint),
    VlessEndpoint() => (address: endpoint.address, port: endpoint.port),
    VmessEndpoint() => (address: endpoint.address, port: endpoint.port),
    ShadowsocksEndpoint() => (address: endpoint.address, port: endpoint.port),
    TrojanEndpoint() => (address: endpoint.address, port: endpoint.port),
    Hysteria2Endpoint() => (address: endpoint.address, port: endpoint.port),
    TuicEndpoint() => (address: endpoint.address, port: endpoint.port),
    SshEndpoint() => (address: endpoint.address, port: endpoint.port),
  };
}

/// WireGuard peers carry `endpoint: host:port` (IPv6 as `[host]:port`).
({String address, int port})? _peerTarget(WireGuardEndpoint endpoint) {
  for (final peer in endpoint.peers) {
    final raw = peer.endpoint.trim();
    if (raw.isEmpty) {
      continue;
    }
    if (raw.startsWith('[')) {
      final close = raw.indexOf(']');
      if (close > 0) {
        final host = raw.substring(1, close);
        final port = int.tryParse(raw.substring(close + 1).replaceAll(':', ''));
        if (host.isNotEmpty && port != null) {
          return (address: host, port: port);
        }
      }
      continue;
    }
    final colon = raw.lastIndexOf(':');
    if (colon > 0) {
      final host = raw.substring(0, colon);
      final port = int.tryParse(raw.substring(colon + 1));
      if (host.isNotEmpty && port != null) {
        return (address: host, port: port);
      }
    }
  }
  return null;
}

/// Live latency snapshot: last sweep time + per-tag samples. Selectors read
/// this; the UI triggers refreshes. Never auto-measures on watch (no
/// surprise network I/O) — [LatencyController.refresh] is the only sweeper.
class LatencyState {
  const LatencyState({this.samples = const <String, int?>{}});

  /// tag → TCP connect latency in ms (null = unreachable or never measured).
  final Map<String, int?> samples;

  String? bestTag() {
    String? best;
    int? bestMs;
    for (final entry in samples.entries) {
      final ms = entry.value;
      if (ms == null) {
        continue;
      }
      if (bestMs == null || ms < bestMs) {
        best = entry.key;
        bestMs = ms;
      }
    }
    return best;
  }
}

/// Owns sweep execution and the cached [LatencyState]. One in-flight sweep
/// at a time; a concurrent call returns the running sweep's future.
///
/// Staleness guard: samples are keyed `tag@address` internally; a sweep
/// drops entries whose address no longer matches the store, so a
/// re-imported tag with a new address never displays the old address's
/// ping (samples for removed/changed endpoints vanish on next refresh).
class LatencyController extends Notifier<LatencyState> {
  Future<LatencyState>? _inFlight;

  @override
  LatencyState build() => const LatencyState();

  Future<LatencyState> refresh({
    LatencyPinger pinger = const SocketLatencyPinger(),
  }) {
    return _inFlight ??= _sweep(pinger).whenComplete(() => _inFlight = null);
  }

  Future<LatencyState> _sweep(LatencyPinger pinger) async {
    final stored = ref.read(endpointStoreProvider).read();
    final targets = <String, ({String address, int port})>{
      // Null-aware entry: endpoints without a probeable address are skipped.
      for (final item in stored) item.tag: ?endpointProbeTarget(item),
    };
    final measured = await measureAll(targets, pinger: pinger);
    // Staleness guard: keep an old sample only when the tag still exists at
    // the same address — a re-imported tag with a new address must not
    // display the old address's ping. Unmeasured-but-unchanged members of
    // the previous sweep stay visible.
    final previousTargets = _previousTargets;
    _previousTargets = targets;
    final samples = <String, int?>{
      for (final entry in state.samples.entries)
        if (targets.containsKey(entry.key) &&
            previousTargets?[entry.key]?.address == targets[entry.key]?.address)
          entry.key: entry.value,
      ...measured,
    };
    final next = LatencyState(samples: samples);
    state = next;
    return next;
  }

  Map<String, ({String address, int port})>? _previousTargets;
}

final latencyProvider = NotifierProvider<LatencyController, LatencyState>(
  LatencyController.new,
);
