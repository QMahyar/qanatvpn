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

  @override
  String get homeEndpoints => 'نقاط پایانی';

  @override
  String get homeNoEndpoints => 'نقطه پایانی نیست';

  @override
  String get homeTapToImport => 'برای درون‌ریزی بزنید';

  @override
  String get homeSplitRules => 'قوانین تفکیک';

  @override
  String get homeSetupGuide => 'راهنمای راه‌اندازی';

  @override
  String get homeNoEndpoint => 'بدون نقطه پایانی';

  @override
  String homeDeadTag(String dead, String tag) {
    return '«$dead» حذف شده — استفاده از $tag';
  }

  @override
  String homeStoredSuffix(int count, String source) {
    return '$count ذخیره‌شده · اتصال: $source';
  }

  @override
  String get endpointsTitle => 'نقاط پایانی';

  @override
  String get endpointsEmpty =>
      'نقطه پایانی نیست. پیوند اشتراک یا نشانی اشتراک را بالا بچسبانید.';

  @override
  String get endpointsImportHint =>
      'vless://… vmess://… https://sub.example.com …';

  @override
  String get endpointsImport => 'درون‌ریزی';

  @override
  String get endpointsAwgProfile => 'نمایه AWG';

  @override
  String get endpointsDelete => 'حذف نقطه پایانی';

  @override
  String get rulesTitle => 'قوانین';

  @override
  String get rulesEmpty =>
      'قانونی نیست. ترافیک از خروجی پیش‌فرض موتور پیروی می‌کند.';

  @override
  String get rulesAdd => 'افزودن قانون';

  @override
  String get rulesEdit => 'ویرایش قانون';

  @override
  String get rulesDelete => 'حذف قانون';

  @override
  String get rulesNew => 'قانون جدید';

  @override
  String get rulesValidationErrors => 'خطاهای اعتبارسنجی';

  @override
  String get rulesOutbound => 'خروجی';

  @override
  String get rulesSave => 'ذخیره';

  @override
  String get rulesCancel => 'لغو';

  @override
  String get rulesNeedCondition => 'پیش از ذخیره دست‌کم یک شرط بیفزایید.';

  @override
  String get rulesEmptyRule => 'قانون خالی';

  @override
  String get groupsTitle => 'گروه‌ها';

  @override
  String get groupsEmpty =>
      'گروهی نیست. برای انتخاب خودکار urltest یا برای جابه‌جایی دستی selector بیفزایید.';

  @override
  String get groupsAdd => 'افزودن گروه';

  @override
  String get groupsEdit => 'ویرایش گروه';

  @override
  String get groupsDelete => 'حذف گروه';

  @override
  String get groupsValidationErrors => 'خطاهای اعتبارسنجی';

  @override
  String get logsTitle => 'گزارش‌ها';

  @override
  String get logsEmpty =>
      'هنوز گزارشی از موتور نیست. برای شروع موتور متصل شوید.';

  @override
  String get logsClear => 'پاک کردن';

  @override
  String get logsLevelAll => 'همه';

  @override
  String get logsLevelErrors => 'فقط خطاها';

  @override
  String get logsSearchHint => 'جست‌وجو در گزارش‌ها';

  @override
  String get logsPause => 'توقف';

  @override
  String get logsResume => 'ادامه';

  @override
  String get logsExport => 'برون‌بری';

  @override
  String get logsExported => 'گزارش‌ها برون‌بری شد';

  @override
  String logsRepeat(int count) {
    return '‹$count بار تکرار شد›';
  }

  @override
  String get diagnosticsTitle => 'عیب‌یابی';

  @override
  String get diagnosticsRefresh => 'به‌روزرسانی';

  @override
  String get updatesTitle => 'به‌روزرسانی‌ها';

  @override
  String get updatesCheckNowButton => 'بررسی الان';
}
