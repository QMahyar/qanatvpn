import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'app/app.dart';
import 'core/services/channel_adapters.dart';
import 'core/services/desktop_platform_adapter.dart';
import 'core/services/tunnel.dart';
import 'core/services/windows_box_process.dart';
import 'modules/logs/log_bus.dart';
import 'modules/routing/policy_store.dart';
import 'modules/routing/rule_store.dart';
import 'modules/updates/updater.dart';
import 'modules/onboarding/split_store.dart';
import 'modules/onboarding/wizard.dart';
import 'modules/sec/firewall.dart';
import 'modules/vpn/logic/vpn_notifier.dart';
import 'modules/vpn/repositories/endpoint_store.dart';
import 'modules/vpn/repositories/profile_config_source.dart';

/// Top-level dispatcher workmanager invokes in the background isolate on
/// Android. Windows has no background scheduler, so it checks on launch.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    return updateCheckBackgroundTask();
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _registerDailyUpdateCheck();
  final PlatformAdapter platform = _platformAdapter();
  final sharedLogBus = LogBus();
  final BoxAdapter box = _boxAdapter(sharedLogBus);
  runApp(
    ProviderScope(
      overrides: [
        platformAdapterProvider.overrideWithValue(platform),
        foregroundAdapterProvider.overrideWithValue(
          MethodChannelForegroundAdapter(),
        ),
        boxAdapterProvider.overrideWithValue(box),
        logBusProvider.overrideWithValue(sharedLogBus),
        firewallAdapterProvider.overrideWithValue(PolicyFirewallAdapter()),
        torAdapterProvider.overrideWithValue(LocalSocksTorAdapter()),
        configSourceProvider.overrideWithValue(
          ProfileConfigSource(
            splitStore: const SplitStore(),
            endpointStore: const EndpointStore(),
            policyStore: const PolicyStore(),
            ruleStore: const RuleStore(),
          ),
        ),
        tunnelProvider.overrideWith((ref) => ref.watch(tunnelAssemblyProvider)),
      ],
      child: const YourVpnApp(),
    ),
  );
}

PlatformAdapter _platformAdapter() {
  if (Platform.isWindows) {
    return const DesktopPlatformAdapter();
  }
  return MethodChannelPlatformAdapter();
}

BoxAdapter _boxAdapter(LogBus logBus) {
  if (Platform.isWindows) {
    return WindowsBoxProcessAdapter();
  }
  return MethodChannelBoxAdapter(logBus: logBus);
}

/// Best-effort: a missing registration must never block app start; the
/// manual check-now path covers the gap.
Future<void> _registerDailyUpdateCheck() async {
  try {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      'yourvpn-updates',
      'updatesDaily',
      frequency: const Duration(hours: 24),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  } on Object {
    // No-op: platform without background scheduling or plugin init failed.
  }
}

/// Enforces the [FirewallPolicy] as base route rules inside the engine
/// profile before start, so kill-switch rules ship with every connect.
class PolicyFirewallAdapter implements FirewallAdapter {
  @override
  Future<void> enforce() async {}

  @override
  Future<void> relax() async {}
}
