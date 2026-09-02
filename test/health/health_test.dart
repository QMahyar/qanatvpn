import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/modules/health/health.dart';

class FakeDnsProber implements DnsProber {
  FakeDnsProber({this.hijacked = false});

  bool hijacked;

  @override
  Future<bool> isHijacked() async => hijacked;
}

class FakePinger implements Pinger {
  FakePinger({this.ms = 20, this.failAfter});

  int ms;
  int? failAfter;
  int calls = 0;

  @override
  Future<int?> ping(String host, int port) async {
    calls += 1;
    if (failAfter != null && calls > failAfter!) {
      return null;
    }
    if (ms < 0) {
      return null;
    }
    return ms;
  }
}

void main() {
  late Health health;
  late FakeDnsProber prober;
  late FakePinger pinger;

  setUp(() {
    prober = FakeDnsProber();
    pinger = FakePinger();
    health = Health(prober: prober, pingerAdapter: pinger);
  });

  test('dead: no hijack + no ping → score 0', () async {
    pinger.ms = -1;
    final report = await health.snapshot();

    expect(report.score, 0);
    expect(report.level, HealthLevel.dead);
    expect(report.pingMs, isNull);
  });

  test('hijack only → 2', () async {
    prober.hijacked = true;
    pinger.ms = -1;
    final report = await health.snapshot();

    expect(report.score, 2);
    expect(report.hijacked, isTrue);
  });

  test('hijack + ping → 4', () async {
    prober.hijacked = true;
    final report = await health.snapshot();

    expect(report.score, 4);
    expect(report.pingMs, 20);
  });

  test('hijack + ping + stable window → 6', () async {
    prober.hijacked = true;
    await health.snapshot();
    await health.snapshot();

    expect((await health.snapshot()).score, 6);
  });

  test('stability drops after failures, score reflects it', () async {
    prober.hijacked = true;
    pinger.failAfter = 3;
    for (var i = 0; i < 3; i++) {
      await health.snapshot();
    }
    final before = await health.snapshot();

    // 3 ok + 1 fail = 75% < 80 → no stability bonus, ping failed → base only
    expect(before.score, 2);

    for (var i = 0; i < 10; i++) {
      await health.snapshot();
    }
    final after = await health.snapshot();

    expect(after.stability, lessThan(75));
    expect(after.score, 2);
  });

  test('health bands: 6 levels map the 0-6 score', () {
    expect(HealthLevel.values.length, 6);
  });
}

