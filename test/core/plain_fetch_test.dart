import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/core/network/plain_fetch.dart';
import 'package:yourvpn/core/services/desktop_platform_adapter.dart';

/// plainFetch maps status/headers/body and closes the client; the desktop
/// adapter reports its safe defaults (engine-managed TUN, no app listing).
void main() {
  test('maps status, multi-value headers, and body', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((HttpRequest request) {
      request.response
        ..statusCode = 201
        ..headers.add('x-multi', 'a')
        ..headers.add('x-multi', 'b')
        ..write('hello');
      request.response.close();
    });

    final response = await plainFetch(
      Uri.parse('http://127.0.0.1:${server.port}/x'),
      const <String, String>{'Accept': '*/*'},
    );

    expect(response.statusCode, 201);
    // Multi-value response headers flatten with ', '.
    expect(response.headers['x-multi'], 'a, b');
    expect(utf8.decode(response.body), 'hello');
  });

  test('unreachable host throws (client closed on the error path)', () async {
    // Port 1 is virtually never bound; connect refuses fast.
    await expectLater(
      plainFetch(Uri.parse('http://127.0.0.1:1/'), const <String, String>{}),
      throwsA(isA<SocketException>()),
    );
  });

  test('DesktopPlatformAdapter safe desktop defaults', () async {
    const adapter = DesktopPlatformAdapter();

    expect(await adapter.isVpnPermissionGranted(), isTrue);
    expect(await adapter.isIgnoringBatteryOptimizations(), isTrue);
    expect(await adapter.isAirplaneMode(), isFalse);
    expect(adapter.engineManagedTun, isTrue);
    expect(await adapter.establish(), isNull);
    expect(await adapter.listInstalledApps(), isEmpty);
  });
}
