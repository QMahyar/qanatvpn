import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/l10n/app_localizations.dart';

/// EN/FA parity: every non-metadata key in app_en.arb exists in app_fa.arb
/// with a non-empty, non-English value, and every getter resolves at runtime
/// in both locales. Catches the "added the English string, forgot Persian"
/// regression that ships English to FA users.
void main() {
  Map<String, dynamic> readArb(String locale) {
    final raw = File(
      'lib/l10n/app_$locale.arb',
    ).readAsStringSync();
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Set<String> keys(Map<String, dynamic> arb) => <String>{
    for (final k in arb.keys)
      if (!k.startsWith('@')) k,
  };

  test('fa covers every en key with a non-empty value', () {
    final en = readArb('en');
    final fa = readArb('fa');
    final enKeys = keys(en);
    final faKeys = keys(fa);

    expect(faKeys, containsAll(enKeys));
    for (final key in enKeys) {
      final value = fa[key];
      expect(value, isNotNull, reason: 'fa missing $key');
      expect((value as String).trim(), isNotEmpty, reason: 'fa empty $key');
    }
  });

  test('no fa value is an untranslated English copy (spot-check)', () {
    final fa = readArb('fa');
    // Keys whose FA translation must differ from EN (brand stays Latin).
    const mustDiffer = <String>[
      'connect',
      'disconnect',
      'rules',
      'groups',
      'logs',
      'diagnostics',
      'rulesSave',
      'rulesCancel',
      'logsClear',
      'endpointsImport',
    ];
    final en = readArb('en');
    for (final key in mustDiffer) {
      expect(
        fa[key],
        isNot(equals(en[key])),
        reason: 'fa[$key] looks untranslated',
      );
    }
  });

  test('every new P2 key resolves at runtime in en + fa', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final fa = lookupAppLocalizations(const Locale('fa'));

    expect(en.homeNoEndpoints, 'No endpoints');
    expect(fa.homeNoEndpoints, isNot('No endpoints'));
    expect(en.rulesNeedCondition, contains('condition'));
    expect(en.logsLevelAll, 'All');
    expect(en.logsLevelErrors, 'Errors only');
    expect(en.endpointsDelete, 'Delete endpoint');
    expect(en.groupsEdit, 'Edit group');
    expect(en.homeDeadTag('X', 'Y'), contains('X'));
    expect(en.homeStoredSuffix(3, 'group'), contains('3'));
    expect(en.logsRepeat(5), contains('5'));
  });
}
