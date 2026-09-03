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

  @override
  Future<void> start(TypedConfig config) async {
    try {
      await channel.invokeMethod<void>('boxStart', {
        'config': json.encode(config.json),
        if (config.includePackages.isNotEmpty)
          'includePackages': config.includePackages,
        if (config.excludePackages.isNotEmpty)
          'excludePackages': config.excludePackages,
      });
      _events.add(const BoxEvent(BoxEventKind.started));
    } on PlatformException catch (e) {
      _events.add(BoxEvent(BoxEventKind.crashed, e));
      throw StateError(e.message ?? e.code);
    }
  }

  @override
  Future<void> stop() async {
    await channel.invokeMethod<void>('boxStop');
    _events.add(const BoxEvent(BoxEventKind.stopped));
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
