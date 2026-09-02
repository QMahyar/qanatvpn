import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/tunnel.dart';

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
  WizardState build() => const WizardState();

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
    state = state.copyWith(
      batteryExempt: true,
      step: WizardStep.perAppSplit,
    );
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

  void finish() {
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
                AppLocalizations.of(context)!.wizardStepOf(state.step.index + 1),
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 12),
              switch (state.step) {
                WizardStep.vpnPermission => _VpnStep(ref: ref, state: state),
                WizardStep.batteryExemption =>
                  _BatteryStep(ref: ref, state: state),
                WizardStep.perAppSplit => _SplitStep(ref: ref, state: state),
                WizardStep.done => const SizedBox.shrink(),
              },
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

class _SplitStep extends StatelessWidget {
  const _SplitStep({required this.ref, required this.state});

  final WidgetRef ref;
  final WizardState state;

  static const List<AppEntry> sampleApps = <AppEntry>[
    AppEntry(packageName: 'org.telegram.messenger', label: 'Telegram'),
    AppEntry(packageName: 'com.android.chrome', label: 'Chrome'),
    AppEntry(packageName: 'com.whatsapp', label: 'WhatsApp'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
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
          selected: <bool>{state.allowMode},
          onSelectionChanged: (Set<bool> selection) =>
              ref.read(wizardProvider.notifier).setAllowMode(selection.first),
        ),
        const SizedBox(height: 12),
        ...sampleApps.map(
          (AppEntry app) => CheckboxListTile(
            title: Text(app.label),
            subtitle: Text(app.packageName),
            value: state.selectedApps.contains(app.packageName),
            onChanged: (_) =>
                ref.read(wizardProvider.notifier).toggleApp(app.packageName),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => ref.read(wizardProvider.notifier).finish(),
          child: Text(l10n.finish),
        ),
      ],
    );
  }
}


