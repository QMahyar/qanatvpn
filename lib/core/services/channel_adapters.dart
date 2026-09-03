import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../modules/logs/log_bus.dart';
import 'tunnel.dart';

/// Real [BoxAdapter] over the `vpn_service` channel.
///
/// Android: Kotlin `BoxEngine` (libbox CommandServer in-process). The channel
/// call blocks until Go's `startOrReloadService` returns, so failures surface
/// here as exceptions and the guarded sequence blocks correctly.
///
/// Runtime events (started/stopped/crashed) arrive Kotlin→Dart on the
/// separate `box_events` channel; the event stream fans them out so
/// [Tunnel] can react to a mid-run engine death.
class MethodChannelBoxAdapter implements BoxAdapter {
  MethodChannelBoxAdapter({
    this.channel = const MethodChannel('vpn_service'),
    LogBus? logBus,
  }) : _logBus = logBus ?? LogBus() {
    const MethodChannel('box_events').setMethodCallHandler(_onEngineEvent);
  }

  final MethodChannel channel;
  final LogBus _logBus;

  final StreamController<BoxEvent> _events =
      StreamController<BoxEvent>.broadcast();

  @override
  Stream<BoxEvent> get events => _events.stream;

  Future<dynamic> _onEngineEvent(MethodCall call) async {
    if (call.method != 'onEngineEvent') {
      return null;
    }
    final String kind = call.arguments['kind'] as String? ?? '';
    final String? message = call.arguments['message'] as String?;
    switch (kind) {
      case 'started':
        _events.add(const BoxEvent(BoxEventKind.started));
      case 'stopped':
        _events.add(const BoxEvent(BoxEventKind.stopped));
      case 'crashed':
        _events.add(
          BoxEvent(BoxEventKind.crashed, StateError(message ?? 'engine died')),
        );
      case 'log':
        _logBus.add(EngineLogLine.parse(message ?? ''));
    }
    return null;
  }

  /// Channel round-trip ceiling: the Kotlin side blocks in
  /// `startOrReloadService`, and an engine wedged there must surface as a
  /// timeout (fail closed) instead of hanging `Tunnel.connect` forever.
  static const Duration startTimeout = Duration(seconds: 30);
  static const Duration stopTimeout = Duration(seconds: 10);

  @override
  Future<void> start(TypedConfig config) async {
    final String payload;
    try {
      payload = json.encode(config.json);
    } on Object catch (e) {
      _events.add(BoxEvent(BoxEventKind.crashed, e));
      throw StateError('config is not JSON-encodable: $e');
    }
    try {
      await channel
          .invokeMethod<void>('boxStart', {
            'config': payload,
            if (config.includePackages.isNotEmpty)
              'includePackages': config.includePackages,
            if (config.excludePackages.isNotEmpty)
              'excludePackages': config.excludePackages,
          })
          .timeout(startTimeout);
      _events.add(const BoxEvent(BoxEventKind.started));
    } on TimeoutException catch (e) {
      _events.add(BoxEvent(BoxEventKind.crashed, e));
      throw StateError('box start timed out: $e');
    } on PlatformException catch (e) {
      _events.add(BoxEvent(BoxEventKind.crashed, e));
      throw StateError(e.message ?? e.code);
    }
  }

  @override
  Future<void> stop() async {
    try {
      await channel.invokeMethod<void>('boxStop').timeout(stopTimeout);
    } on TimeoutException {
      // Engine wedged: the tunnel layer already treats stop failure as a
      // crash event; rethrow so Tunnel.disconnect can fail closed.
      rethrow;
    } finally {
      _events.add(const BoxEvent(BoxEventKind.stopped));
    }
  }
}

/// Foreground notification service over the same channel.
class MethodChannelForegroundAdapter implements ForegroundAdapter {
  MethodChannelForegroundAdapter({
    this.channel = const MethodChannel('vpn_service'),
  });

  final MethodChannel channel;

  @override
  Future<void> start() =>
      channel.invokeMethod<void>('startForeground').onError((_, _) {});

  @override
  Future<void> stop() =>
      channel.invokeMethod<void>('stopForeground').onError((_, _) {});
}

/// Tor SOCKS probe on 127.0.0.1:9050. The Tor sidecar is a later milestone;
/// until it exists the port is down, which correctly blocks TOR-CHAIN tags.
class LocalSocksTorAdapter implements TorAdapter {
  LocalSocksTorAdapter({this.host = '127.0.0.1', this.port = 9050});

  final String host;
  final int port;

  @override
  Future<bool> isSocksUp() async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(milliseconds: 500),
      );
      socket.destroy();
      return true;
    } on Object {
      return false;
    }
  }
}
