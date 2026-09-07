import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fa'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'YOURVPN'**
  String get appTitle;

  /// Connect button
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @vpnPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'VPN permission'**
  String get vpnPermissionTitle;

  /// No description provided for @vpnPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'Android needs your consent to create a VPN tunnel. A system dialog will appear.'**
  String get vpnPermissionBody;

  /// No description provided for @vpnPermissionGrant.
  ///
  /// In en, this message translates to:
  /// **'Grant VPN permission'**
  String get vpnPermissionGrant;

  /// No description provided for @vpnPermissionGranted.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get vpnPermissionGranted;

  /// No description provided for @batteryTitle.
  ///
  /// In en, this message translates to:
  /// **'Battery exemption'**
  String get batteryTitle;

  /// No description provided for @batteryBody.
  ///
  /// In en, this message translates to:
  /// **'Without an exemption, Android may kill the tunnel in Doze. VPN apps are allowed to request this.'**
  String get batteryBody;

  /// No description provided for @batteryAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get batteryAllow;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @perAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Per-app split'**
  String get perAppTitle;

  /// No description provided for @allowlist.
  ///
  /// In en, this message translates to:
  /// **'Allowlist'**
  String get allowlist;

  /// No description provided for @bypass.
  ///
  /// In en, this message translates to:
  /// **'Bypass'**
  String get bypass;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @wizardStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of 3'**
  String wizardStepOf(int step);

  /// No description provided for @wizardSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip setup'**
  String get wizardSkip;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageSystemShort.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get settingsLanguageSystemShort;

  /// No description provided for @settingsConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get settingsConnection;

  /// No description provided for @settingsAutoConnect.
  ///
  /// In en, this message translates to:
  /// **'Auto-connect'**
  String get settingsAutoConnect;

  /// No description provided for @settingsAutoConnectSub.
  ///
  /// In en, this message translates to:
  /// **'Connect the last endpoint on launch'**
  String get settingsAutoConnectSub;

  /// No description provided for @settingsReconnect.
  ///
  /// In en, this message translates to:
  /// **'Auto-reconnect'**
  String get settingsReconnect;

  /// No description provided for @settingsReconnectSub.
  ///
  /// In en, this message translates to:
  /// **'Retry after connection drops (5 attempts)'**
  String get settingsReconnectSub;

  /// No description provided for @updatesIdle.
  ///
  /// In en, this message translates to:
  /// **'No check yet. The app checks daily in the background.'**
  String get updatesIdle;

  /// No description provided for @updatesUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to date (v{version})'**
  String updatesUpToDate(String version);

  /// No description provided for @updatesCheckNow.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get updatesCheckNow;

  /// No description provided for @updatesInstall.
  ///
  /// In en, this message translates to:
  /// **'Download & install'**
  String get updatesInstall;

  /// No description provided for @groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// No description provided for @rules.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get rules;

  /// No description provided for @logs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// No description provided for @diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// No description provided for @stateConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get stateConnected;

  /// No description provided for @stateConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get stateConnecting;

  /// No description provided for @stateDisconnecting.
  ///
  /// In en, this message translates to:
  /// **'Disconnecting…'**
  String get stateDisconnecting;

  /// No description provided for @stateBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get stateBlocked;

  /// No description provided for @stateReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get stateReconnecting;

  /// No description provided for @stateTapToConnect.
  ///
  /// In en, this message translates to:
  /// **'Tap to connect'**
  String get stateTapToConnect;

  /// No description provided for @blockVpnPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'VPN permission denied'**
  String get blockVpnPermissionDenied;

  /// No description provided for @blockEstablishFailed.
  ///
  /// In en, this message translates to:
  /// **'Tunnel setup failed'**
  String get blockEstablishFailed;

  /// No description provided for @blockAirplaneMode.
  ///
  /// In en, this message translates to:
  /// **'Airplane mode is on'**
  String get blockAirplaneMode;

  /// No description provided for @blockTorDown.
  ///
  /// In en, this message translates to:
  /// **'Tor chain is down'**
  String get blockTorDown;

  /// No description provided for @blockBoxStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Engine failed to start'**
  String get blockBoxStartFailed;

  /// No description provided for @blockBoxCrashed.
  ///
  /// In en, this message translates to:
  /// **'Engine crashed'**
  String get blockBoxCrashed;

  /// No description provided for @homeEndpoints.
  ///
  /// In en, this message translates to:
  /// **'Endpoints'**
  String get homeEndpoints;

  /// No description provided for @homeNoEndpoints.
  ///
  /// In en, this message translates to:
  /// **'No endpoints'**
  String get homeNoEndpoints;

  /// No description provided for @homeTapToImport.
  ///
  /// In en, this message translates to:
  /// **'Tap to import'**
  String get homeTapToImport;

  /// No description provided for @homeSplitRules.
  ///
  /// In en, this message translates to:
  /// **'Split rules'**
  String get homeSplitRules;

  /// No description provided for @homeSetupGuide.
  ///
  /// In en, this message translates to:
  /// **'Setup guide'**
  String get homeSetupGuide;

  /// No description provided for @homeNoEndpoint.
  ///
  /// In en, this message translates to:
  /// **'no endpoint'**
  String get homeNoEndpoint;

  /// No description provided for @homeDeadTag.
  ///
  /// In en, this message translates to:
  /// **'“{dead}” gone — using {tag}'**
  String homeDeadTag(String dead, String tag);

  /// No description provided for @homeStoredSuffix.
  ///
  /// In en, this message translates to:
  /// **'{count} stored · connect: {source}'**
  String homeStoredSuffix(int count, String source);

  /// No description provided for @endpointsTitle.
  ///
  /// In en, this message translates to:
  /// **'Endpoints'**
  String get endpointsTitle;

  /// No description provided for @endpointsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No endpoints. Paste a share link or subscription URL above.'**
  String get endpointsEmpty;

  /// No description provided for @endpointsImportHint.
  ///
  /// In en, this message translates to:
  /// **'vless://… vmess://… https://sub.example.com …'**
  String get endpointsImportHint;

  /// No description provided for @endpointsImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get endpointsImport;

  /// No description provided for @endpointsAwgProfile.
  ///
  /// In en, this message translates to:
  /// **'AWG profile'**
  String get endpointsAwgProfile;

  /// No description provided for @endpointsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete endpoint'**
  String get endpointsDelete;

  /// No description provided for @rulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get rulesTitle;

  /// No description provided for @rulesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No rules. Traffic follows the engine default outbound.'**
  String get rulesEmpty;

  /// No description provided for @rulesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add rule'**
  String get rulesAdd;

  /// No description provided for @rulesEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit rule'**
  String get rulesEdit;

  /// No description provided for @rulesDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete rule'**
  String get rulesDelete;

  /// No description provided for @rulesNew.
  ///
  /// In en, this message translates to:
  /// **'New rule'**
  String get rulesNew;

  /// No description provided for @rulesValidationErrors.
  ///
  /// In en, this message translates to:
  /// **'Validation errors'**
  String get rulesValidationErrors;

  /// No description provided for @rulesOutbound.
  ///
  /// In en, this message translates to:
  /// **'Outbound'**
  String get rulesOutbound;

  /// No description provided for @rulesSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get rulesSave;

  /// No description provided for @rulesCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get rulesCancel;

  /// No description provided for @rulesNeedCondition.
  ///
  /// In en, this message translates to:
  /// **'Add at least one condition before saving.'**
  String get rulesNeedCondition;

  /// No description provided for @rulesEmptyRule.
  ///
  /// In en, this message translates to:
  /// **'empty rule'**
  String get rulesEmptyRule;

  /// No description provided for @groupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groupsTitle;

  /// No description provided for @groupsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No groups. Add a urltest for auto-select or a selector for manual switching.'**
  String get groupsEmpty;

  /// No description provided for @groupsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add group'**
  String get groupsAdd;

  /// No description provided for @groupsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit group'**
  String get groupsEdit;

  /// No description provided for @groupsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get groupsDelete;

  /// No description provided for @groupsValidationErrors.
  ///
  /// In en, this message translates to:
  /// **'Validation errors'**
  String get groupsValidationErrors;

  /// No description provided for @logsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logsTitle;

  /// No description provided for @logsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No engine logs yet. Connect to start the engine.'**
  String get logsEmpty;

  /// No description provided for @logsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get logsClear;

  /// No description provided for @logsLevelAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get logsLevelAll;

  /// No description provided for @logsLevelErrors.
  ///
  /// In en, this message translates to:
  /// **'Errors only'**
  String get logsLevelErrors;

  /// No description provided for @logsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search logs'**
  String get logsSearchHint;

  /// No description provided for @logsPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get logsPause;

  /// No description provided for @logsResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get logsResume;

  /// No description provided for @logsExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get logsExport;

  /// No description provided for @logsExported.
  ///
  /// In en, this message translates to:
  /// **'Logs exported'**
  String get logsExported;

  /// No description provided for @logsRepeat.
  ///
  /// In en, this message translates to:
  /// **'‹repeated {count} times›'**
  String logsRepeat(int count);

  /// No description provided for @diagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnosticsTitle;

  /// No description provided for @diagnosticsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get diagnosticsRefresh;

  /// No description provided for @updatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updatesTitle;

  /// No description provided for @updatesCheckNowButton.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get updatesCheckNowButton;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fa'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fa':
      return AppLocalizationsFa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
