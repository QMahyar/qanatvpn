// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'YOURVPN';

  @override
  String get connect => 'Connect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get settings => 'Settings';

  @override
  String get vpnPermissionTitle => 'VPN permission';

  @override
  String get vpnPermissionBody =>
      'Android needs your consent to create a VPN tunnel. A system dialog will appear.';

  @override
  String get vpnPermissionGrant => 'Grant VPN permission';

  @override
  String get vpnPermissionGranted => 'Granted';

  @override
  String get batteryTitle => 'Battery exemption';

  @override
  String get batteryBody =>
      'Without an exemption, Android may kill the tunnel in Doze. VPN apps are allowed to request this.';

  @override
  String get batteryAllow => 'Allow';

  @override
  String get skip => 'Skip';

  @override
  String get perAppTitle => 'Per-app split';

  @override
  String get allowlist => 'Allowlist';

  @override
  String get bypass => 'Bypass';

  @override
  String get finish => 'Finish';

  @override
  String wizardStepOf(int step) {
    return 'Step $step of 3';
  }

  @override
  String get updatesIdle =>
      'No check yet. The app checks daily in the background.';

  @override
  String updatesUpToDate(String version) {
    return 'Up to date (v$version)';
  }

  @override
  String get updatesCheckNow => 'Check now';

  @override
  String get updatesInstall => 'Download & install';

  @override
  String get groups => 'Groups';

  @override
  String get rules => 'Rules';

  @override
  String get logs => 'Logs';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get stateConnected => 'Connected';

  @override
  String get stateConnecting => 'Connecting…';

  @override
  String get stateDisconnecting => 'Disconnecting…';

  @override
  String get stateBlocked => 'Blocked';

  @override
  String get stateReconnecting => 'Reconnecting…';

  @override
  String get stateTapToConnect => 'Tap to connect';

  @override
  String get blockVpnPermissionDenied => 'VPN permission denied';

  @override
  String get blockEstablishFailed => 'Tunnel setup failed';

  @override
  String get blockAirplaneMode => 'Airplane mode is on';

  @override
  String get blockTorDown => 'Tor chain is down';

  @override
  String get blockBoxStartFailed => 'Engine failed to start';

  @override
  String get blockBoxCrashed => 'Engine crashed';
}
