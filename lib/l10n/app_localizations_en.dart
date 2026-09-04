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

  @override
  String get homeEndpoints => 'Endpoints';

  @override
  String get homeNoEndpoints => 'No endpoints';

  @override
  String get homeTapToImport => 'Tap to import';

  @override
  String get homeSplitRules => 'Split rules';

  @override
  String get homeSetupGuide => 'Setup guide';

  @override
  String get homeNoEndpoint => 'no endpoint';

  @override
  String homeDeadTag(String dead, String tag) {
    return '“$dead” gone — using $tag';
  }

  @override
  String homeStoredSuffix(int count, String source) {
    return '$count stored · connect: $source';
  }

  @override
  String get endpointsTitle => 'Endpoints';

  @override
  String get endpointsEmpty =>
      'No endpoints. Paste a share link or subscription URL above.';

  @override
  String get endpointsImportHint =>
      'vless://… vmess://… https://sub.example.com …';

  @override
  String get endpointsImport => 'Import';

  @override
  String get endpointsAwgProfile => 'AWG profile';

  @override
  String get endpointsDelete => 'Delete endpoint';

  @override
  String get rulesTitle => 'Rules';

  @override
  String get rulesEmpty =>
      'No rules. Traffic follows the engine default outbound.';

  @override
  String get rulesAdd => 'Add rule';

  @override
  String get rulesEdit => 'Edit rule';

  @override
  String get rulesDelete => 'Delete rule';

  @override
  String get rulesNew => 'New rule';

  @override
  String get rulesValidationErrors => 'Validation errors';

  @override
  String get rulesOutbound => 'Outbound';

  @override
  String get rulesSave => 'Save';

  @override
  String get rulesCancel => 'Cancel';

  @override
  String get rulesNeedCondition => 'Add at least one condition before saving.';

  @override
  String get rulesEmptyRule => 'empty rule';

  @override
  String get groupsTitle => 'Groups';

  @override
  String get groupsEmpty =>
      'No groups. Add a urltest for auto-select or a selector for manual switching.';

  @override
  String get groupsAdd => 'Add group';

  @override
  String get groupsEdit => 'Edit group';

  @override
  String get groupsDelete => 'Delete group';

  @override
  String get groupsValidationErrors => 'Validation errors';

  @override
  String get logsTitle => 'Logs';

  @override
  String get logsEmpty => 'No engine logs yet. Connect to start the engine.';

  @override
  String get logsClear => 'Clear';

  @override
  String get logsLevelAll => 'All';

  @override
  String get logsLevelErrors => 'Errors only';

  @override
  String get logsSearchHint => 'Search logs';

  @override
  String get logsPause => 'Pause';

  @override
  String get logsResume => 'Resume';

  @override
  String get logsExport => 'Export';

  @override
  String get logsExported => 'Logs exported';

  @override
  String logsRepeat(int count) {
    return '‹repeated $count times›';
  }

  @override
  String get diagnosticsTitle => 'Diagnostics';

  @override
  String get diagnosticsRefresh => 'Refresh';

  @override
  String get updatesTitle => 'Updates';

  @override
  String get updatesCheckNowButton => 'Check now';
}
