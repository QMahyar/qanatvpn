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
    return WindowsBoxProcessAdapter(logBus: logBus);
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

/// Kill-switch adapter: packet filtering itself is engine-owned (sing-box
/// `route.rules` + the platform TUN), so this adapter is the ordering +
/// verification half. Enforce fails closed: the vendored profile and every
/// assembled config are checked for the hijack-first ordering before the
/// engine is allowed to carry traffic, and a missing guarantee blocks the
/// connect instead of leaking.
///
/// Platform note: a true OS-level fail-closed filter (device-wide block-all
/// except the tunnel, surviving engine death) needs native code that does not
/// exist yet on either platform — Android `VpnService` `setBlocking(true)` +
/// `addRoute(0.0.0.0/0)` lockdown in `YourVpnService`, Windows WFP rules in
/// the runner. Until those land, the engine rule ordering below is the
/// kill-switch; see `scripts/leak_test.sh` scenario coverage.
class PolicyFirewallAdapter implements FirewallAdapter {
  PolicyFirewallAdapter({this.policy = const FirewallPolicy()});

  final FirewallPolicy policy;
  FirewallPolicy get _policy => policy;

  bool _enforced = false;

  @override
  Future<void> enforce() async {
    final errors = _policy.validateOrdering(_policy.baseRules());
    if (errors.isNotEmpty) {
      throw StateError('kill-switch policy invalid: ${errors.join('; ')}');
    }
    _enforced = true;
  }

  @override
  Future<void> relax() async {
    _enforced = false;
  }

  /// Fail-closed query for diagnostics: true while the tunnel must be
  /// filtering (connected/blocked), false after a clean disconnect.
  bool get enforced => _enforced;
}
