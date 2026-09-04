import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:workmanager/workmanager.dart';

import 'app/app.dart';
import 'core/network/http_cache.dart';
import 'core/startup/app_startup.dart';
import 'core/services/channel_adapters.dart';
import 'core/services/desktop_platform_adapter.dart';
import 'core/services/tunnel.dart';
import 'core/services/windows_box_process.dart';
import 'modules/logs/log_bus.dart';
import 'modules/geo/geo_asset.dart';
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
/// The local version is stamped into inputData so the background isolate
/// can persist a meaningful comparison without a plugin channel there.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final Map<dynamic, dynamic>? data = inputData;
    final localVersion = data?['localVersion'] as String?;
    return updateCheckBackgroundTask(localVersion: localVersion);
  });
}

Future<void> main() async {
  final Stopwatch total = Stopwatch()..start();
  final PhaseTimer timer = PhaseTimer();
  WidgetsFlutterBinding.ensureInitialized();
  final PlatformAdapter platform = await timer.timed(
    'platformAdapter',
    () async => _platformAdapter(),
  );
  final LogBus sharedLogBus = await timer.timed(
    'logBus',
    () async => LogBus(),
  );
  final BoxAdapter box = await timer.timed(
    'boxAdapter',
    () async => _boxAdapter(sharedLogBus),
  );
  total.stop();
  latestStartupReport = timer.report(total.elapsed);
  if (kDebugMode) {
    final String phases = timer.phases.entries
        .map((e) => '${e.key}=${e.value.inMilliseconds}ms')
        .join(' ');
    debugPrint('startup total=${total.elapsed.inMilliseconds}ms $phases');
  }
  // Deferred past first frame: Workmanager().initialize can block plugin
  // init on the critical path. Manual check-now covers any missed window.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_deferredStartup());
  });
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

/// Deferred startup: daily update-check registration + geo asset seeding.
/// Each step is best-effort — a failure here must never block app start;
/// the manual check-now path and `ensure()`'s bundled fallback cover gaps.
Future<void> _deferredStartup() async {
  await _registerDailyUpdateCheck();
  await _seedGeoAssets();
}

Future<void> _registerDailyUpdateCheck() async {
  try {
    await Workmanager().initialize(callbackDispatcher);
    String version = '';
    try {
      version = (await PackageInfo.fromPlatform()).version;
    } on Object {
      // Unknown version: the background task then stores an empty
      // localVersion and restart comparison stays conservative.
    }
    await Workmanager().registerPeriodicTask(
      'yourvpn-updates',
      'updatesDaily',
      frequency: const Duration(hours: 24),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      inputData: <String, String>{'localVersion': version},
    );
  } on Object {
    // No-op: platform without background scheduling or plugin init failed.
  }
}

/// Seeds every registered SRS into the app cache before any config build
/// can reference it (`getPath` has no existence check by design — startup
/// is the existence guarantee). Best-effort refresh afterward: fresh bytes
/// when online, bundled fallback standing in when offline.
Future<void> _seedGeoAssets() async {
  try {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    final geo = GeoAsset(
      cacheDir: Directory('$home/.yourvpn/geo'),
      initialDir: Directory(GeoAsset.initialAssetDir),
      // Disk-backed so ETag revalidation survives restarts — without it the
      // daily refresh re-downloads from raw.githubusercontent on every
      // launch, re-exposing the 60/hr unauthenticated rate limit.
      http: HttpCache(
        fetch: plainFetch,
        cacheDir: Directory('$home/.yourvpn/geo/http'),
      ),
    );
    for (final tag in GeoAsset.registry.keys) {
      try {
        await geo.ensure(tag);
      } on Object {
        continue;
      }
    }
    try {
      await geo.refreshAll();
    } on Object {
      // Offline / rate-limited: bundled or stale bytes stay authoritative.
    }
  } on Object {
    // Geo seeding must never block startup.
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
