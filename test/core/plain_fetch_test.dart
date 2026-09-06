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
    String? seenUa;
    server.listen((HttpRequest request) {
      seenUa = request.headers.value('user-agent');
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
    // GitHub API 403s UA-less clients: default UA injected when caller
    // supplies none (dart:io prepends its own marker, so assert containment).
    expect(seenUa, contains(kDefaultUserAgent));
  });

  test('caller-supplied User-Agent is preserved, not overwritten', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    String? seenUa;
    server.listen((HttpRequest request) {
      seenUa = request.headers.value('user-agent');
      request.response.write('ok');
      request.response.close();
    });

    await plainFetch(
      Uri.parse('http://127.0.0.1:${server.port}/x'),
      const <String, String>{'User-Agent': 'custom-agent/1.0'},
    );

    // Caller UA survives (dart:io prepends its own marker).
    expect(seenUa, contains('custom-agent/1.0'));
    expect(seenUa, isNot(contains(kDefaultUserAgent)));
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
