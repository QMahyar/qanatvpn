import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/core/services/channel_adapters.dart';
import 'package:yourvpn/core/services/tunnel.dart';
import 'package:yourvpn/modules/logs/log_bus.dart';

/// Production-path coverage for the MethodChannel seam: arg shapes, event
/// fan-out, error mapping, and the Tor SOCKS probe. Tunnel tests use fakes;
/// these exercise the real adapter against a mocked channel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const vpnChannel = MethodChannel('vpn_service');
  const boxEventsChannel = MethodChannel('box_events');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(vpnChannel, null);
  });

  void mockVpn(Future<dynamic> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(vpnChannel, handler);
  }

  TypedConfig config({
    List<String> include = const <String>[],
    List<String> exclude = const <String>[],
  }) => TypedConfig(
    tag: 't-1',
    json: <String, dynamic>{'route': <String, dynamic>{}},
    includePackages: include,
    excludePackages: exclude,
  );

  group('MethodChannelBoxAdapter.start/stop', () {
    test('sends boxStart with encoded config + packages, emits started',
        () async {
      Map<String, dynamic>? args;
      mockVpn((call) async {
        args = Map<String, dynamic>.from(call.arguments as Map);
        return null;
      });
      final adapter = MethodChannelBoxAdapter(logBus: LogBus());
      final events = <BoxEvent>[];
      final sub = adapter.events.listen(events.add);
      addTearDown(sub.cancel);

      await adapter.start(
        config(include: <String>['com.a'], exclude: <String>['com.b']),
      );
      await Future<void>.delayed(Duration.zero);

      expect(args?['config'], json.encode(config().json));
      expect(args?['includePackages'], <String>['com.a']);
      expect(args?['excludePackages'], <String>['com.b']);
      expect(events.single.kind, BoxEventKind.started);
    });

    test('omits empty package lists from boxStart args', () async {
      Map<String, dynamic>? args;
      mockVpn((call) async {
        args = Map<String, dynamic>.from(call.arguments as Map);
        return null;
      });
      final adapter = MethodChannelBoxAdapter(logBus: LogBus());

      await adapter.start(config());

      expect(args?.containsKey('includePackages'), isFalse);
      expect(args?.containsKey('excludePackages'), isFalse);
    });

    test('PlatformException → StateError + crashed event', () async {
      mockVpn((call) async {
        throw PlatformException(code: 'box_start_failed', message: 'boom');
      });
      final adapter = MethodChannelBoxAdapter(logBus: LogBus());
      final events = <BoxEvent>[];
      final sub = adapter.events.listen(events.add);
      addTearDown(sub.cancel);

      await expectLater(adapter.start(config()), throwsStateError);
      await Future<void>.delayed(Duration.zero);
      expect(events.single.kind, BoxEventKind.crashed);
    });

    test('stop sends boxStop and emits stopped', () async {
      String? method;
      mockVpn((call) async {
        method = call.method;
        return null;
      });
      final adapter = MethodChannelBoxAdapter(logBus: LogBus());
      final events = <BoxEvent>[];
      final sub = adapter.events.listen(events.add);
      addTearDown(sub.cancel);

      await adapter.stop();
      await Future<void>.delayed(Duration.zero);

      expect(method, 'boxStop');
      expect(events.single.kind, BoxEventKind.stopped);
    });
  });

  group('box_events fan-out', () {
    Future<void> sendEngineEvent(String kind, [String? message]) {
      return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            boxEventsChannel.name,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('onEngineEvent', <String, dynamic>{
                'kind': kind,
                'message': message,
              }),
            ),
            (_) {},
          );
    }

    test('log lines land in LogBus', () async {
      mockVpn((call) async => null);
      final bus = LogBus();
      MethodChannelBoxAdapter(logBus: bus);

      await sendEngineEvent('log', 'ERROR dial failed');
      await Future<void>.delayed(Duration.zero);

      expect(bus.lines.single.isError, isTrue);
      expect(bus.lines.single.message, 'dial failed');
    });

    test('crashed fans out to events with the engine message', () async {
      mockVpn((call) async => null);
      final adapter = MethodChannelBoxAdapter(logBus: LogBus());
      final events = <BoxEvent>[];
      final sub = adapter.events.listen(events.add);
      addTearDown(sub.cancel);

      await sendEngineEvent('crashed', 'FATAL bad config');
      await Future<void>.delayed(Duration.zero);

      expect(events.single.kind, BoxEventKind.crashed);
      expect(events.single.error.toString(), contains('FATAL bad config'));
    });

    test('started/stopped fan out', () async {
      mockVpn((call) async => null);
      final adapter = MethodChannelBoxAdapter(logBus: LogBus());
      final events = <BoxEvent>[];
      final sub = adapter.events.listen(events.add);
      addTearDown(sub.cancel);

      await sendEngineEvent('started');
      await sendEngineEvent('stopped');
      await Future<void>.delayed(Duration.zero);

      expect(
        events.map((e) => e.kind).toList(),
        <BoxEventKind>[BoxEventKind.started, BoxEventKind.stopped],
      );
    });
  });

  group('LocalSocksTorAdapter', () {
    test('open port → true, closed port → false', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      final open = LocalSocksTorAdapter(port: server.port);
      expect(await open.isSocksUp(), isTrue);

      final closed = LocalSocksTorAdapter(port: 1);
      expect(await closed.isSocksUp(), isFalse);
    });
  });
}
