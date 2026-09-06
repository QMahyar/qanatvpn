import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/modules/updates/update_installer.dart';

/// UpdateVerifier: download + sha256-verify pipeline (audit W1.5 — update
/// artifacts were installed with zero integrity checks before).
void main() {
  late HttpServer server;
  late int port;
  // 64-char payload string; sha256 computed over those exact bytes.
  const payload = '0000000000000000000000000000000000000000000000000000000000000000';
  const payloadSha256 = '60e05bd1b195af2f94112fa7197a5c88289058840ce7c6df9693756bc6250f55';

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    port = server.port;
  });

  tearDown(() => server.close(force: true));

  void serve({
    String body = payload,
    int status = 200,
    String? shaPath,
    String? shaBody,
  }) {
    server.listen((request) async {
      if (shaPath != null && request.uri.path == shaPath) {
        request.response.statusCode = 200;
        request.response.write(shaBody ?? '$payloadSha256  asset.bin');
        await request.response.close();
        return;
      }
      request.response.statusCode = status;
      request.response.write(body);
      await request.response.close();
    });
  }

  test('downloads and verifies matching sha256', () async {
    serve();
    final verifier = UpdateVerifier();
    final file = await verifier.downloadVerified(
      Uri.parse('http://127.0.0.1:$port/asset.bin'),
      payloadSha256,
    );
    addTearDown(() => file.delete());
    expect(utf8.decode(await file.readAsBytes()), payload);
  });

  test('mismatched sha256 throws and deletes the artifact', () async {
    serve();
    final verifier = UpdateVerifier();
    int ourTempFiles() => Directory.systemTemp
        .listSync()
        .whereType<File>()
        .where(
          (f) => f.uri.pathSegments.last.startsWith('yourvpn_update_'),
        )
        .length;
    final before = ourTempFiles();
    await expectLater(
      verifier.downloadVerified(
        Uri.parse('http://127.0.0.1:$port/asset.bin'),
        'a${'a' * 62}',
      ),
      throwsA(isA<VerifyException>()),
    );
    // Give async delete a beat; the rejected artifact must not linger.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(ourTempFiles(), before);
  });

  test('no digest anywhere fails closed without downloading', () async {
    serve();
    final verifier = UpdateVerifier();
    await expectLater(
      verifier.downloadVerified(Uri.parse('http://127.0.0.1:$port/asset.bin'), null),
      throwsA(isA<VerifyException>()),
    );
  });

  test('digestResolver failure fails closed (no install without digest)', () async {
    serve();
    final verifier = UpdateVerifier();
    await expectLater(
      verifier.downloadVerified(
        Uri.parse('http://127.0.0.1:$port/asset.bin'),
        null,
        digestResolver: () async => null,
      ),
      throwsA(isA<VerifyException>()),
    );
  });

  test('digestResolver supplies the digest when expectedSha256 is null', () async {
    serve();
    final verifier = UpdateVerifier();
    final file = await verifier.downloadVerified(
      Uri.parse('http://127.0.0.1:$port/asset.bin'),
      null,
      digestResolver: () async => payloadSha256,
    );
    addTearDown(() => file.delete());
    expect(await file.length(), greaterThan(0));
  });

  test('siblingDigest parses sha256sum output from the sibling URL', () async {
    serve(shaPath: '/asset.bin.sha256', shaBody: '$payloadSha256  asset.bin\n');
    final verifier = UpdateVerifier();
    final digest = await verifier.siblingDigest(
      Uri.parse('http://127.0.0.1:$port/asset.bin'),
    );
    expect(digest, payloadSha256);
  });

  test('siblingDigest returns null on HTTP 404 sibling', () async {
    server.listen((request) async {
      request.response.statusCode = 404;
      await request.response.close();
    });
    final verifier = UpdateVerifier();
    final digest = await verifier.siblingDigest(
      Uri.parse('http://127.0.0.1:$port/asset.bin'),
    );
    expect(digest, isNull);
  });

  group('parseDigestFile', () {
    test('sha256sum format', () {
      expect(
        UpdateVerifier.parseDigestFile('$payloadSha256  asset.bin\n'),
        payloadSha256,
      );
    });

    test('bare hex', () {
      expect(UpdateVerifier.parseDigestFile(payloadSha256), payloadSha256);
    });

    test('uppercase hex normalized to lowercase', () {
      expect(
        UpdateVerifier.parseDigestFile(payloadSha256.toUpperCase()),
        payloadSha256,
      );
    });

    test('garbage returns null', () {
      expect(UpdateVerifier.parseDigestFile('not a digest'), isNull);
      expect(UpdateVerifier.parseDigestFile(''), isNull);
    });
  });

  test('non-200 download throws VerifyException', () async {
    serve(status: 403);
    final verifier = UpdateVerifier();
    await expectLater(
      verifier.downloadVerified(
        Uri.parse('http://127.0.0.1:$port/asset.bin'),
        payloadSha256,
      ),
      throwsA(isA<VerifyException>()),
    );
  });
}
