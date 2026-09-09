import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qanatvpn/core/services/tunnel.dart';
import 'package:qanatvpn/modules/onboarding/split_store.dart';
import 'package:qanatvpn/modules/onboarding/wizard.dart';

class _FakePlatformAdapter implements PlatformAdapter {
  bool vpnGranted = false;
  bool batteryExempt = false;
  int vpnPermissionRequests = 0;
  int batteryRequests = 0;

  @override
  Future<bool> isVpnPermissionGranted() async => vpnGranted;

  @override
  Future<void> requestVpnPermission() async {
    vpnPermissionRequests += 1;
    vpnGranted = true;
  }

  @override
  Future<bool> isIgnoringBatteryOptimizations() async => batteryExempt;

  @override
  Future<void> requestIgnoreBatteryOptimizations() async {
    batteryRequests += 1;
    batteryExempt = true;
  }

  @override
  Future<bool> isAirplaneMode() async => false;

  @override
  bool get engineManagedTun => false;

  @override
  Future<int?> establish() async => null;

  @override
  void protect(int fd) {}

  @override
  void closeFd(int fd) {}

  @override
  Future<List<InstalledApp>> listInstalledApps() async =>
      const <InstalledApp>[];
}

void main() {
  late _FakePlatformAdapter platform;
  late Directory tempDir;
  late ProviderContainer container;

  setUp(() async {
    platform = _FakePlatformAdapter();
    tempDir = await Directory.systemTemp.createTemp('qanatvpn-wizard');
    container = ProviderContainer(
      overrides: [
        platformAdapterProvider.overrideWithValue(platform),
        splitStoreProvider.overrideWithValue(
          SplitStore(baseDir: tempDir.path),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  WizardState state() => container.read(wizardProvider);

  test('starts at step 1 with vpn not granted', () {
    expect(state().step, WizardStep.vpnPermission);
    expect(state().vpnGranted, isFalse);
  });

  test('requestVpnPermission advances to battery step on grant', () async {
    await container.read(wizardProvider.notifier).requestVpnPermission();

    expect(platform.vpnPermissionRequests, 1);
    expect(state().vpnGranted, isTrue);
    expect(state().step, WizardStep.batteryExemption);
  });

  test('battery request fires then moves to per-app step', () async {
    await container.read(wizardProvider.notifier).requestVpnPermission();
    await container.read(wizardProvider.notifier).requestBatteryExemption();

    expect(platform.batteryRequests, 1);
    expect(state().batteryExempt, isTrue);
    expect(state().step, WizardStep.perAppSplit);
  });

  test('skipBattery moves to per-app without requesting', () async {
    await container.read(wizardProvider.notifier).requestVpnPermission();
    await container.read(wizardProvider.notifier).skipBattery();

    expect(platform.batteryRequests, 0);
    expect(state().step, WizardStep.perAppSplit);
  });

  test('app selection toggles + allow mode switch + finish', () async {
    final notifier = container.read(wizardProvider.notifier);
    await notifier.requestVpnPermission();
    await notifier.skipBattery();

    notifier.toggleApp('org.telegram.messenger');
    notifier.toggleApp('com.whatsapp');
    expect(state().selectedApps, <String>{
      'org.telegram.messenger',
      'com.whatsapp',
    });

    notifier.toggleApp('org.telegram.messenger');
    expect(state().selectedApps, <String>{'com.whatsapp'});

    notifier.setAllowMode(false);
    expect(state().isAllowlist, isFalse);

    await notifier.finish();
    expect(state().step, WizardStep.done);
  });

  test('back navigates battery→vpn and per-app→battery', () async {
    final notifier = container.read(wizardProvider.notifier);
    await notifier.requestVpnPermission();
    expect(state().step, WizardStep.batteryExemption);

    notifier.back();
    expect(state().step, WizardStep.vpnPermission);

    await notifier.requestVpnPermission();
    await notifier.skipBattery();
    notifier.back();
    expect(state().step, WizardStep.batteryExemption);
  });

  // Audit W2.3: completion must persist — the wizard re-ran on every cold
  // start and there was no way past a declined consent dialog.
  test('skipAll records completion and lands on done', () async {
    await container.read(wizardProvider.notifier).skipAll();

    expect(state().step, WizardStep.done);
    final store = SplitStore(baseDir: tempDir.path);
    expect(store.wizardDone, isTrue);
    // Skip with no apps = no split decision recorded.
    expect(store.read(), isNull);
  });

  test('finish with selection records completion + split choice', () async {
    final notifier = container.read(wizardProvider.notifier);
    notifier.toggleApp('org.telegram.messenger');
    await notifier.finish();

    final store = SplitStore(baseDir: tempDir.path);
    expect(store.wizardDone, isTrue);
    expect(store.read()!.packages, <String>{'org.telegram.messenger'});
  });

  test('a completed wizard starts at done on a fresh container (no re-run)',
      () async {
    await container.read(wizardProvider.notifier).skipAll();

    // Simulate the next app launch: new container over the same store dir.
    final container2 = ProviderContainer(
      overrides: [
        platformAdapterProvider.overrideWithValue(platform),
        splitStoreProvider.overrideWithValue(
          SplitStore(baseDir: tempDir.path),
        ),
      ],
    );
    addTearDown(container2.dispose);

    expect(container2.read(wizardProvider).step, WizardStep.done);
  });
}
