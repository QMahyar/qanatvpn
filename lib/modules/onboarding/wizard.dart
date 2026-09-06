import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/tunnel.dart';
import 'split_store.dart';

/// App list entry for the per-app picker.
class AppEntry {
  const AppEntry({required this.packageName, required this.label});

  final String packageName;
  final String label;
}

/// Wizard state machine: 3 steps + done.
enum WizardStep { vpnPermission, batteryExemption, perAppSplit, done }

class WizardState {
  const WizardState({
    this.step = WizardStep.vpnPermission,
    this.vpnGranted = false,
    this.batteryExempt = false,
    this.allowMode = true,
    this.selectedApps = const <String>{},
  });

  final WizardStep step;
  final bool vpnGranted;
  final bool batteryExempt;

  /// true = only selected apps go through the tunnel (allowlist);
  /// false = selected apps bypass the tunnel (bypass list).
  final bool allowMode;
  final Set<String> selectedApps;

  bool get isAllowlist => allowMode;

  WizardState copyWith({
    WizardStep? step,
    bool? vpnGranted,
    bool? batteryExempt,
    bool? allowMode,
    Set<String>? selectedApps,
  }) {
    return WizardState(
      step: step ?? this.step,
      vpnGranted: vpnGranted ?? this.vpnGranted,
      batteryExempt: batteryExempt ?? this.batteryExempt,
      allowMode: allowMode ?? this.allowMode,
      selectedApps: selectedApps ?? this.selectedApps,
    );
  }
}

class WizardController extends Notifier<WizardState> {
  @override
  WizardState build() {
    // Audit W2.3: the wizard re-ran on every cold start because completion
    // was never persisted. A previously-finished onboarding skips straight
    // to done (home shows immediately); the wizard can still be re-opened
    // from settings once W2.2 lands.
    final done = ref.read(splitStoreProvider).wizardDone;
    if (done) {
      return const WizardState(step: WizardStep.done);
    }
    return const WizardState();
  }

  Future<void> checkVpnPermission() async {
    final platform = ref.read(platformAdapterProvider);
    final granted = await platform.isVpnPermissionGranted();
    state = state.copyWith(vpnGranted: granted);
  }

  Future<void> requestVpnPermission() async {
    final platform = ref.read(platformAdapterProvider);
    await platform.requestVpnPermission();
    final granted = await platform.isVpnPermissionGranted();
    state = state.copyWith(
      vpnGranted: granted,
      step: granted ? WizardStep.batteryExemption : WizardStep.vpnPermission,
    );
  }

  Future<void> requestBatteryExemption() async {
    final platform = ref.read(platformAdapterProvider);
    final exempt = await platform.isIgnoringBatteryOptimizations();
    if (!exempt) {
      await platform.requestIgnoreBatteryOptimizations();
    }
    state = state.copyWith(batteryExempt: true, step: WizardStep.perAppSplit);
  }

  Future<void> skipBattery() async {
    state = state.copyWith(step: WizardStep.perAppSplit);
  }

  void toggleApp(String packageName) {
    final next = <String>{...state.selectedApps};
    if (!next.remove(packageName)) {
      next.add(packageName);
    }
    state = state.copyWith(selectedApps: next);
  }

  void setAllowMode(bool allow) {
    state = state.copyWith(allowMode: allow);
  }

  /// Persists the split decision so every connect applies it via the config
  /// source; empty selection = no split (whole-device tunnel). Completion
  /// is always recorded so the wizard does not re-run next launch.
  Future<void> finish() async {
    final store = ref.read(splitStoreProvider);
    if (state.selectedApps.isNotEmpty) {
      await store.save(
        SplitChoice(allowMode: state.allowMode, packages: state.selectedApps),
      );
    } else {
      await store.clear();
      await store.markDone();
    }
    state = state.copyWith(step: WizardStep.done);
  }

  /// Skips the rest of onboarding: records completion (whole-device
  /// tunnel) and lands on home. Audit W2.3 — previously there was no way
  /// past the wizard without completing every step.
  Future<void> skipAll() async {
    final store = ref.read(splitStoreProvider);
    await store.clear();
    await store.markDone();
    state = state.copyWith(step: WizardStep.done);
  }

  void back() {
    final target = switch (state.step) {
      WizardStep.batteryExemption => WizardStep.vpnPermission,
      WizardStep.perAppSplit => WizardStep.batteryExemption,
      _ => state.step,
    };
    state = state.copyWith(step: target);
  }
}

/// Injected platform adapter for the wizard (same instance the Tunnel uses).
final platformAdapterProvider = Provider<PlatformAdapter>((ref) {
  throw UnimplementedError('override with the real adapter in main.dart');
});

/// Split choice persistence; overridden in main.dart with a real base dir on
/// desktop and left default (HOME-based) on mobile.
final splitStoreProvider = Provider<SplitStore>((ref) => const SplitStore());

final wizardProvider = NotifierProvider<WizardController, WizardState>(
  WizardController.new,
);

/// Guided 3-step onboarding: VPN permission → battery exemption → per-app
/// split. Each step is one system interaction, skippable where safe.
class Wizard extends ConsumerWidget {
  const Wizard({super.key, this.onDone});

  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wizardProvider);
    final theme = Theme.of(context);

    if (state.step == WizardStep.done) {
      onDone?.call();
      return const SizedBox.shrink();
    }

    return Directionality(
      textDirection: Directionality.of(context),
      child: Card(
        margin: const EdgeInsetsDirectional.all(16),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AppLocalizations.of(
                  context,
                )!.wizardStepOf(state.step.index + 1),
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 12),
              switch (state.step) {
                WizardStep.vpnPermission => _VpnStep(ref: ref, state: state),
                WizardStep.batteryExemption => _BatteryStep(
                  ref: ref,
                  state: state,
                ),
                WizardStep.perAppSplit => _SplitStep(ref: ref, state: state),
                WizardStep.done => const SizedBox.shrink(),
              },
              const SizedBox(height: 8),
              // Audit W2.3: a user who declines the VPN consent dialog was
              // dead-ended — the app was unreachable without completing the
              // wizard. Skip is always available and lands on home with a
              // whole-device-tunnel default.
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () =>
                      ref.read(wizardProvider.notifier).skipAll(),
                  child: Text(
                    AppLocalizations.of(context)!.wizardSkip,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VpnStep extends StatelessWidget {
  const _VpnStep({required this.ref, required this.state});

  final WidgetRef ref;
  final WizardState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.vpnPermissionTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(l10n.vpnPermissionBody),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: state.vpnGranted
              ? null
              : () => ref.read(wizardProvider.notifier).requestVpnPermission(),
          child: Text(
            state.vpnGranted
                ? l10n.vpnPermissionGranted
                : l10n.vpnPermissionGrant,
          ),
        ),
      ],
    );
  }
}

class _BatteryStep extends StatelessWidget {
  const _BatteryStep({required this.ref, required this.state});

  final WidgetRef ref;
  final WizardState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.batteryTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(l10n.batteryBody),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            FilledButton(
              onPressed: () =>
                  ref.read(wizardProvider.notifier).requestBatteryExemption(),
              child: Text(l10n.batteryAllow),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => ref.read(wizardProvider.notifier).skipBattery(),
              child: Text(l10n.skip),
            ),
          ],
        ),
      ],
    );
  }
}

class _SplitStep extends ConsumerStatefulWidget {
  const _SplitStep({required this.ref, required this.state});

  final WidgetRef ref;
  final WizardState state;

  @override
  ConsumerState<_SplitStep> createState() => _SplitStepState();
}

class _SplitStepState extends ConsumerState<_SplitStep> {
  List<AppEntry> _apps = const <AppEntry>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    final platform = widget.ref.read(platformAdapterProvider);
    // A hung PackageManager must never strand the wizard on the spinner:
    // fall through to the existing empty-state path ("No user apps found"
    // + Finish stays enabled).
    final installed = await platform.listInstalledApps().timeout(
      const Duration(milliseconds: 1500),
      onTimeout: () => const <InstalledApp>[],
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _apps = <AppEntry>[
        for (final app in installed)
          AppEntry(packageName: app.packageName, label: app.label),
      ];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final apps = _apps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.perAppTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: <ButtonSegment<bool>>[
            ButtonSegment<bool>(value: true, label: Text(l10n.allowlist)),
            ButtonSegment<bool>(value: false, label: Text(l10n.bypass)),
          ],
          selected: <bool>{widget.state.allowMode},
          onSelectionChanged: (Set<bool> selection) => widget.ref
              .read(wizardProvider.notifier)
              .setAllowMode(selection.first),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsetsDirectional.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (apps.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.all(8),
            child: Text('No user apps found', style: theme.textTheme.bodySmall),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: apps.length,
              itemBuilder: (BuildContext context, int index) {
                final AppEntry app = apps[index];
                return CheckboxListTile(
                  title: Text(app.label),
                  subtitle: Text(app.packageName),
                  value: widget.state.selectedApps.contains(app.packageName),
                  onChanged: (_) => widget.ref
                      .read(wizardProvider.notifier)
                      .toggleApp(app.packageName),
                );
              },
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => widget.ref.read(wizardProvider.notifier).finish(),
          child: Text(l10n.finish),
        ),
      ],
    );
  }
}
