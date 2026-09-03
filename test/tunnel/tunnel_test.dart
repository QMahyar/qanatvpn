import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/core/services/tunnel.dart';

/// Records every step so tests can assert the guarded ordering.
class FakePlatformAdapter implements PlatformAdapter {
  FakePlatformAdapter({
    this.log,
    this.permissionGranted = true,
    this.batteryExempt = true,
    this.airplane = false,
    this.establishResult = 42,
    this.engineManagedTun = false,
  });

  /// Shared recorder across all fakes, preserves true interleaving.
  final List<String>? log;

  bool permissionGranted;
  bool batteryExempt;
  bool airplane;
  int? establishResult;

  @override
  bool engineManagedTun;

  final List<String> calls = <String>[];

  void _mark(String step) {
    calls.add(step);
    log?.add(step);
  }

  @override
  Future<bool> isVpnPermissionGranted() async {
    _mark('isVpnPermissionGranted');
    return permissionGranted;
  }

  @override
  Future<void> requestVpnPermission() async {
    _mark('requestVpnPermission');
    permissionGranted = true;
  }

  @override
  Future<bool> isIgnoringBatteryOptimizations() async {
    _mark('isIgnoringBatteryOptimizations');
    return batteryExempt;
  }

  @override
  Future<void> requestIgnoreBatteryOptimizations() async {
    _mark('requestIgnoreBatteryOptimizations');
    batteryExempt = true;
  }

  @override
  Future<bool> isAirplaneMode() async {
    _mark('isAirplaneMode');
    return airplane;
  }

  @override
  Future<int?> establish() async {
    _mark('establish');
    return establishResult;
  }

  @override
  Future<List<InstalledApp>> listInstalledApps() async =>
      const <InstalledApp>[];

  @override
  void protect(int fd) {
    _mark('protect:$fd');
  }

  @override
  void closeFd(int fd) {
    _mark('closeFd:$fd');
  }
}

class FakeForegroundAdapter implements ForegroundAdapter {
  FakeForegroundAdapter({this.log});

  final List<String>? log;

  @override
  Future<void> start() async {
    log?.add('foreground:start');
  }

  @override
  Future<void> stop() async {
    log?.add('foreground:stop');
  }
}

class FakeBoxAdapter implements BoxAdapter {
  FakeBoxAdapter({
    this.log,
    this.startThrows = false,
    this.startDelay = Duration.zero,
  });

  final List<String>? log;

  bool startThrows;
  Duration startDelay;

  final StreamController<BoxEvent> _events =
      StreamController<BoxEvent>.broadcast();

  final List<String> calls = <String>[];
  TypedConfig? lastConfig;

  @override
  Stream<BoxEvent> get events => _events.stream;

  @override
  Future<void> start(TypedConfig config) async {
    log?.add('box:start:${config.tag}');
    calls.add('box:start:${config.tag}');
    lastConfig = config;
    if (startDelay != Duration.zero) {
      await Future<void>.delayed(startDelay);
    }
    if (startThrows) {
      throw StateError('box refused');
    }
    _events.add(const BoxEvent(BoxEventKind.started));
  }

  @override
  Future<void> stop() async {
    log?.add('box:stop');
    calls.add('box:stop');
    _events.add(const BoxEvent(BoxEventKind.stopped));
  }

  void crash() {
    _events.add(BoxEvent(BoxEventKind.crashed, StateError('died')));
  }
}

class FakeFirewallAdapter implements FirewallAdapter {
  FakeFirewallAdapter({this.log});

  final List<String>? log;

  final List<String> calls = <String>[];

  @override
  Future<void> enforce() async {
    log?.add('firewall:enforce');
    calls.add('firewall:enforce');
  }

  @override
  Future<void> relax() async {
    log?.add('firewall:relax');
    calls.add('firewall:relax');
  }
}

class FakeTorAdapter implements TorAdapter {
  FakeTorAdapter({this.log, this.socksUp = true});

  final List<String>? log;

  bool socksUp;

  final List<String> calls = <String>[];

  @override
  Future<bool> isSocksUp() async {
    log?.add('tor:isSocksUp');
    calls.add('tor:isSocksUp');
    return socksUp;
  }
}

class FakeConfigSource implements ConfigSource {
  FakeConfigSource({this.requiresTor = false, this.resolveThrows = false});

  bool requiresTor;
  bool resolveThrows;

  final List<String> tags = <String>[];

  @override
  Future<TypedConfig> resolve(String tag) async {
    tags.add(tag);
    if (resolveThrows) {
      throw StateError('unknown tag');
    }
    return TypedConfig(
      tag: tag,
      json: <String, dynamic>{'outbound': tag},
      requiresTor: requiresTor,
    );
  }
}

Tunnel buildTunnel({
  required FakePlatformAdapter platform,
  required FakeBoxAdapter box,
  required FakeFirewallAdapter firewall,
  required FakeConfigSource config,
  FakeForegroundAdapter? foreground,
  FakeTorAdapter? tor,
}) {
  return Tunnel(
    platform: platform,
    foreground: foreground ?? FakeForegroundAdapter(),
    box: box,
    firewall: firewall,
    tor: tor ?? FakeTorAdapter(),
    configSource: config,
  );
}

List<String> sharedLog() => <String>[];

void main() {
  group('Tunnel.connect guarded sequence', () {
    test(
      'happy path runs grant→battery→foreground→establish→protect→start→firewall',
      () async {
        final log = sharedLog();
        final platform = FakePlatformAdapter(log: log);
        final box = FakeBoxAdapter(log: log);
        final firewall = FakeFirewallAdapter(log: log);
        final config = FakeConfigSource();
        final foreground = FakeForegroundAdapter(log: log);
        final tor = FakeTorAdapter(log: log);
        final tunnel = buildTunnel(
          platform: platform,
          box: box,
          firewall: firewall,
          config: config,
          foreground: foreground,
          tor: tor,
        );

        await tunnel.connect('HKG-02');

        expect(tunnel.state, TunnelState.connected);
        expect(config.tags, <String>['HKG-02']);
        expect(box.lastConfig?.tag, 'HKG-02');
        expect(log, <String>[
          'isVpnPermissionGranted',
          'isIgnoringBatteryOptimizations',
          'foreground:start',
          'isAirplaneMode',
          'establish',
          'protect:42',
          'box:start:HKG-02',
          'firewall:enforce',
        ]);
        expect(tunnel.blockReason, isNull);
        await tunnel.dispose();
      },
    );

    test(
      'permission denied → blocked with firewall enforced, no establish',
      () async {
        final platform = FakePlatformAdapter(permissionGranted: false);
        final box = FakeBoxAdapter();
        final firewall = FakeFirewallAdapter();
        final tunnel = buildTunnel(
          platform: platform,
          box: box,
          firewall: firewall,
          config: FakeConfigSource(),
        );

        await tunnel.connect('HKG-02');

        expect(tunnel.state, TunnelState.blocked);
        expect(tunnel.blockReason, TunnelBlockReason.vpnPermissionDenied);
        expect(platform.calls.contains('establish'), isFalse);
        expect(box.calls, isEmpty);
        expect(firewall.calls, <String>['firewall:enforce']);
        await tunnel.dispose();
      },
    );

    test(
      'airplane mode → blocked before establish, fd never created',
      () async {
        final platform = FakePlatformAdapter(airplane: true);
        final box = FakeBoxAdapter();
        final firewall = FakeFirewallAdapter();
        final tunnel = buildTunnel(
          platform: platform,
          box: box,
          firewall: firewall,
          config: FakeConfigSource(),
        );

        await tunnel.connect('HKG-02');

        expect(tunnel.state, TunnelState.blocked);
        expect(tunnel.blockReason, TunnelBlockReason.airplaneMode);
        expect(platform.calls.contains('establish'), isFalse);
        await tunnel.dispose();
      },
    );

    test(
      'tor down → blocked fallback, box never starts (upstream #4200)',
      () async {
        final platform = FakePlatformAdapter();
        final box = FakeBoxAdapter();
        final firewall = FakeFirewallAdapter();
        final tor = FakeTorAdapter(socksUp: false);
        final config = FakeConfigSource(requiresTor: true);
        final tunnel = buildTunnel(
          platform: platform,
          box: box,
          firewall: firewall,
          config: config,
          tor: tor,
        );

        await tunnel.connect('TOR-CHAIN');

        expect(tunnel.state, TunnelState.blocked);
        expect(tunnel.blockReason, TunnelBlockReason.torDown);
        expect(platform.calls.contains('establish'), isFalse);
        expect(box.calls, isEmpty);
        expect(firewall.calls, <String>['firewall:enforce']);
        await tunnel.dispose();
      },
    );

    test('establish failure → closeFd on null fd path, blocked', () async {
      final platform = FakePlatformAdapter(establishResult: null);
      final tunnel = buildTunnel(
        platform: platform,
        box: FakeBoxAdapter(),
        firewall: FakeFirewallAdapter(),
        config: FakeConfigSource(),
      );

      await tunnel.connect('HKG-02');

      expect(tunnel.state, TunnelState.blocked);
      expect(tunnel.blockReason, TunnelBlockReason.establishFailed);
      expect(platform.calls.contains('protect:42'), isFalse);
      await tunnel.dispose();
    });

    test(
      'box start failure → fd closed + blocked, no firewall leak window',
      () async {
        final platform = FakePlatformAdapter();
        final box = FakeBoxAdapter(startThrows: true);
        final firewall = FakeFirewallAdapter();
        final tunnel = buildTunnel(
          platform: platform,
          box: box,
          firewall: firewall,
          config: FakeConfigSource(),
        );

        await tunnel.connect('HKG-02');

        expect(tunnel.state, TunnelState.blocked);
        expect(tunnel.blockReason, TunnelBlockReason.boxStartFailed);
        expect(platform.calls, contains('closeFd:42'));
        expect(firewall.calls, <String>['firewall:enforce']);
        await tunnel.dispose();
      },
    );

    test('unknown tag → blocked', () async {
      final tunnel = buildTunnel(
        platform: FakePlatformAdapter(),
        box: FakeBoxAdapter(),
        firewall: FakeFirewallAdapter(),
        config: FakeConfigSource(resolveThrows: true),
      );

      await tunnel.connect('NOPE-01');

      expect(tunnel.state, TunnelState.blocked);
      expect(tunnel.blockReason, TunnelBlockReason.establishFailed);
    });
  });

  group('Tunnel engine-managed TUN (libbox 1.14 openTun path)', () {
    test(
      'happy path runs grant→battery→foreground→start→firewall, no fd steps',
      () async {
        final log = sharedLog();
        final platform = FakePlatformAdapter(log: log, engineManagedTun: true);
        final box = FakeBoxAdapter(log: log);
        final firewall = FakeFirewallAdapter(log: log);
        final foreground = FakeForegroundAdapter(log: log);
        final tunnel = buildTunnel(
          platform: platform,
          box: box,
          firewall: firewall,
          config: FakeConfigSource(),
          foreground: foreground,
        );

        await tunnel.connect('HKG-02');

        expect(tunnel.state, TunnelState.connected);
        expect(log, <String>[
          'isVpnPermissionGranted',
          'isIgnoringBatteryOptimizations',
          'foreground:start',
          'isAirplaneMode',
          'box:start:HKG-02',
          'firewall:enforce',
        ]);
        expect(platform.calls.any((c) => c.startsWith('establish')), isFalse);
        expect(platform.calls.any((c) => c.startsWith('protect')), isFalse);
        expect(platform.calls.any((c) => c.startsWith('closeFd')), isFalse);
        await tunnel.dispose();
      },
    );

    test(
      'box start failure → blocked, engine owns the fd so no closeFd',
      () async {
        final platform = FakePlatformAdapter(engineManagedTun: true);
        final box = FakeBoxAdapter(startThrows: true);
        final firewall = FakeFirewallAdapter();
        final tunnel = buildTunnel(
          platform: platform,
          box: box,
          firewall: firewall,
          config: FakeConfigSource(),
        );

        await tunnel.connect('HKG-02');

        expect(tunnel.state, TunnelState.blocked);
        expect(tunnel.blockReason, TunnelBlockReason.boxStartFailed);
        expect(platform.calls.any((c) => c.startsWith('closeFd')), isFalse);
        expect(firewall.calls, <String>['firewall:enforce']);
        await tunnel.dispose();
      },
    );

    test('disconnect reverses without fd steps', () async {
      final log = sharedLog();
      final platform = FakePlatformAdapter(log: log, engineManagedTun: true);
      final box = FakeBoxAdapter(log: log);
      final tunnel = buildTunnel(
        platform: platform,
        box: box,
        firewall: FakeFirewallAdapter(log: log),
        config: FakeConfigSource(),
        foreground: FakeForegroundAdapter(log: log),
      );

      await tunnel.connect('HKG-02');
      log.clear();
      await tunnel.disconnect();

      expect(log, <String>['box:stop', 'foreground:stop', 'firewall:relax']);
      expect(platform.calls.any((c) => c.startsWith('closeFd')), isFalse);
      await tunnel.dispose();
    });
  });

  group('Tunnel.disconnect', () {
    test(
      'reverses in order: box stop → fd close → foreground stop → firewall relax',
      () async {
        final log = sharedLog();
        final platform = FakePlatformAdapter(log: log);
        final box = FakeBoxAdapter(log: log);
        final firewall = FakeFirewallAdapter(log: log);
        final foreground = FakeForegroundAdapter(log: log);
        final tunnel = buildTunnel(
          platform: platform,
          box: box,
          firewall: firewall,
          config: FakeConfigSource(),
          foreground: foreground,
        );

        await tunnel.connect('HKG-02');
        log.clear();

        await tunnel.disconnect();

        expect(tunnel.state, TunnelState.disconnected);
        expect(log, <String>[
          'box:stop',
          'closeFd:42',
          'foreground:stop',
          'firewall:relax',
        ]);
      },
    );

    test('disconnect when disconnected is a no-op', () async {
      final platform = FakePlatformAdapter();
      final box = FakeBoxAdapter();
      final tunnel = buildTunnel(
        platform: platform,
        box: box,
        firewall: FakeFirewallAdapter(),
        config: FakeConfigSource(),
      );

      await tunnel.disconnect();

      expect(tunnel.state, TunnelState.disconnected);
      expect(box.calls, isEmpty);
      expect(platform.calls, isEmpty);
    });

    test('connect twice is idempotent while connecting/connected', () async {
      final box = FakeBoxAdapter(startDelay: const Duration(milliseconds: 50));
      final tunnel = buildTunnel(
        platform: FakePlatformAdapter(),
        box: box,
        firewall: FakeFirewallAdapter(),
        config: FakeConfigSource(),
      );

      final first = tunnel.connect('HKG-02');
      final second = tunnel.connect('TYO-01');
      await Future.wait(<Future<void>>[first, second]);

      expect(box.lastConfig?.tag, 'HKG-02');
      expect(box.calls.where((c) => c.startsWith('box:start')), hasLength(1));
      await tunnel.dispose();
    });
  });

  group('Tunnel.status stream + crash', () {
    test('status stream emits every transition', () async {
      final tunnel = buildTunnel(
        platform: FakePlatformAdapter(),
        box: FakeBoxAdapter(),
        firewall: FakeFirewallAdapter(),
        config: FakeConfigSource(),
      );
      final seen = <TunnelState>[];
      final sub = tunnel.status.listen(seen.add);

      await tunnel.connect('HKG-02');
      await tunnel.disconnect();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(
        seen,
        containsAll(<TunnelState>[
          TunnelState.connecting,
          TunnelState.connected,
          TunnelState.disconnecting,
          TunnelState.disconnected,
        ]),
      );
      await tunnel.dispose();
    });

    test('box crash while connected → blocked + firewall enforced', () async {
      final platform = FakePlatformAdapter();
      final box = FakeBoxAdapter();
      final firewall = FakeFirewallAdapter();
      final tunnel = buildTunnel(
        platform: platform,
        box: box,
        firewall: firewall,
        config: FakeConfigSource(),
      );

      await tunnel.connect('HKG-02');
      expect(tunnel.state, TunnelState.connected);

      box.crash();
      await Future<void>.delayed(Duration.zero);

      expect(tunnel.state, TunnelState.blocked);
      expect(tunnel.blockReason, TunnelBlockReason.boxCrashed);
      expect(
        firewall.calls.where((c) => c == 'firewall:enforce'),
        hasLength(2),
      );
      await tunnel.dispose();
    });

    test(
      'battery not exempt → request fires, connect continues (wizard owns UX)',
      () async {
        final platform = FakePlatformAdapter(batteryExempt: false);
        final tunnel = buildTunnel(
          platform: platform,
          box: FakeBoxAdapter(),
          firewall: FakeFirewallAdapter(),
          config: FakeConfigSource(),
        );

        await tunnel.connect('HKG-02');

        expect(platform.calls, contains('requestIgnoreBatteryOptimizations'));
        expect(tunnel.state, TunnelState.connected);
        await tunnel.dispose();
      },
    );
  });
}
