import 'tunnel.dart';

/// Windows/desktop [PlatformAdapter]: no VpnService consent dialog, no
/// airplane-mode API, no package manager. Everything returns the safe
/// desktop default. The TUN is engine-managed (wintun opened by the
/// sing-box.exe subprocess), matching the Android openTun path.
class DesktopPlatformAdapter implements PlatformAdapter {
  const DesktopPlatformAdapter();

  @override
  Future<bool> isVpnPermissionGranted() async => true;

  @override
  Future<void> requestVpnPermission() async {}

  @override
  Future<bool> isIgnoringBatteryOptimizations() async => true;

  @override
  Future<void> requestIgnoreBatteryOptimizations() async {}

  @override
  Future<bool> isAirplaneMode() async => false;

  @override
  bool get engineManagedTun => true;

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
