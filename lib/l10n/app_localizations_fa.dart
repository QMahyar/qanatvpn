// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get appTitle => 'YOURVPN';

  @override
  String get connect => 'اتصال';

  @override
  String get disconnect => 'قطع اتصال';

  @override
  String get settings => 'تنظیمات';

  @override
  String get vpnPermissionTitle => 'مجوز VPN';

  @override
  String get vpnPermissionBody =>
      'اندروید برای ساخت تونل VPN به اجازه شما نیاز دارد. یک دیالوگ سیستمی ظاهر می‌شود.';

  @override
  String get vpnPermissionGrant => 'اعطای مجوز VPN';

  @override
  String get vpnPermissionGranted => 'اعطا شد';

  @override
  String get batteryTitle => 'معافیت باتری';

  @override
  String get batteryBody =>
      'بدون معافیت، اندروید ممکن است تونل را در حالت Doze بکشد. برنامه‌های VPN مجاز به درخواست این هستند.';

  @override
  String get batteryAllow => 'اجازه دادن';

  @override
  String get skip => 'رد کردن';

  @override
  String get perAppTitle => 'تقسیم بر اساس برنامه';

  @override
  String get allowlist => 'فهرست مجاز';

  @override
  String get bypass => 'دور زدن';

  @override
  String get finish => 'پایان';

  @override
  String wizardStepOf(int step) {
    return 'مرحله $step از 3';
  }

  @override
  String get updatesIdle =>
      'هنوز بررسی نشده. برنامه روزانه در پس‌زمینه بررسی می‌کند.';

  @override
  String updatesUpToDate(String version) {
    return 'به‌روز است (v$version)';
  }

  @override
  String get updatesCheckNow => 'بررسی الان';

  @override
  String get updatesInstall => 'دانلود و نصب';

  @override
  String get groups => 'گروه‌ها';

  @override
  String get rules => 'قوانین';

  @override
  String get logs => 'گزارش‌ها';

  @override
  String get diagnostics => 'عیب‌یابی';

  @override
  String get stateConnected => 'متصل';

  @override
  String get stateConnecting => 'در حال اتصال…';

  @override
  String get stateDisconnecting => 'در حال قطع…';

  @override
  String get stateBlocked => 'مسدود';

  @override
  String get stateReconnecting => 'در حال اتصال مجدد…';

  @override
  String get stateTapToConnect => 'برای اتصال بزنید';

  @override
  String get blockVpnPermissionDenied => 'مجوز VPN رد شد';

  @override
  String get blockEstablishFailed => 'راه‌اندازی تونل ناموفق بود';

  @override
  String get blockAirplaneMode => 'حالت هواپیما روشن است';

  @override
  String get blockTorDown => 'زنجیره تور قطع است';

  @override
  String get blockBoxStartFailed => 'موتور شروع نشد';

  @override
  String get blockBoxCrashed => 'موتور متوقف شد';
}
