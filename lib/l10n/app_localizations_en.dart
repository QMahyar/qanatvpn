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
}
