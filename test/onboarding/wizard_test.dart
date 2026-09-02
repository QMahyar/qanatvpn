import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/core/services/tunnel.dart';
import 'package:yourvpn/modules/onboarding/wizard.dart';

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
  Future<int?> establish() async => null;

  @override
  void protect(int fd) {}

  @override
  void closeFd(int fd) {}
}

void main() {
  late _FakePlatformAdapter platform;
  late ProviderContainer container;

  setUp(() {
    platform = _FakePlatformAdapter();
    container = ProviderContainer(
      overrides: [platformAdapterProvider.overrideWithValue(platform)],
    );
  });

  tearDown(() => container.dispose());

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
    expect(state().selectedApps, <String>{'org.telegram.messenger', 'com.whatsapp'});

    notifier.toggleApp('org.telegram.messenger');
    expect(state().selectedApps, <String>{'com.whatsapp'});

    notifier.setAllowMode(false);
    expect(state().isAllowlist, isFalse);

    notifier.finish();
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
}
