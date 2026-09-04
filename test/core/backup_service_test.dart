import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart' show SecretBoxAuthenticationError;
import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/core/backup/backup_service.dart';
import 'package:yourvpn/modules/onboarding/split_store.dart';
import 'package:yourvpn/modules/routing/policy_store.dart';
import 'package:yourvpn/modules/routing/routing_policy.dart';
import 'package:yourvpn/modules/routing/rule_store.dart';
import 'package:yourvpn/modules/vpn/repositories/endpoint_store.dart';
import 'package:yourvpn/modules/vpn/repositories/ingestion/ingestion_adapter.dart';

void main() {
  late Directory dir;
  late BackupService service;

  late EndpointStore endpoints;
  late RuleStore rules;
  late PolicyStore policy;
  late SplitStore split;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('backup-test');
    endpoints = EndpointStore(baseDir: dir.path);
    rules = RuleStore(baseDir: dir.path);
    policy = PolicyStore(baseDir: dir.path);
    split = SplitStore(baseDir: dir.path);
    service = BackupService(
      endpointStore: endpoints,
      ruleStore: rules,
      policyStore: policy,
      splitStore: split,
    );
  });

  tearDown(() {
    dir.deleteSync(recursive: true);
  });

  StoredEndpoint trojan(String tag) => StoredEndpoint(
    endpoint: TrojanEndpoint(tag: tag, address: 'a', port: 443, password: 'p'),
    label: tag,
  );

  test('export → wipe → import(replace) restores every store', () async {
    await endpoints.save(<StoredEndpoint>[
      trojan('t1'),
      trojan('t2'),
    ]);
    await rules.save(
      const RuleDocument(rules: []),
    );
    await policy.save(
      const PolicyDocument(
        groups: <OutboundGroup>[
          OutboundGroup.urlTest(tag: 'auto', members: <String>['t1', 't2']),
        ],
        leafOutbounds: <String>['t1', 't2'],
      ),
    );
    await split.save(
      const SplitChoice(allowMode: true, packages: <String>{'com.a'}),
    );

    final path = '${dir.path}/backup.qnv';
    final bytes = await service.export(path, 'correct horse');
    expect(bytes, greaterThan(0));

    // Wipe: overwrite stores with empty content.
    await endpoints.save(<StoredEndpoint>[]);
    await policy.save(
      const PolicyDocument(groups: <OutboundGroup>[], leafOutbounds: <String>[]),
    );

    final summary = await service.import(path, 'correct horse');
    expect(summary.endpoints, 2);
    expect(summary.groups, 1);

    final restoredEndpoints = endpoints.read();
    expect(restoredEndpoints.map((e) => e.tag), <String>['t1', 't2']);
    final restoredPolicy = policy.read();
    expect(restoredPolicy.groups.single.tag, 'auto');
    expect(restoredPolicy.groups.single.isUrlTest, isTrue);
    final restoredSplit = split.read();
    expect(restoredSplit?.allowMode, isTrue);
    expect(restoredSplit?.packages, <String>{'com.a'});
  });

  test('wrong password fails with authentication error, store untouched',
      () async {
    await endpoints.save(<StoredEndpoint>[trojan('t1')]);
    final path = '${dir.path}/backup.qnv';
    await service.export(path, 'right');
    await endpoints.save(<StoredEndpoint>[]);

    await expectLater(
      service.import(path, 'wrong'),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
    // Import failed closed: store stays empty, no partial application.
    expect(endpoints.read(), isEmpty);
  });

  test('corrupt envelope fails with BackupFormatException', () async {
    final path = '${dir.path}/bad.qnv';
    await File(path).writeAsString('{"magic": "nope"}');

    await expectLater(
      service.inspect(path, 'pw'),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('non-JSON garbage fails with BackupFormatException', () async {
    final path = '${dir.path}/garbage.qnv';
    await File(path).writeAsString('not json at all');

    await expectLater(
      service.inspect(path, 'pw'),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('merge folds endpoints/groups by tag (backup wins), appends rules',
      () async {
    await endpoints.save(<StoredEndpoint>[trojan('t1')]);
    final path = '${dir.path}/backup.qnv';
    await service.export(path, 'pw');

    // Diverge local state after export.
    await endpoints.save(<StoredEndpoint>[
      trojan('t1'),
      trojan('local-only'),
    ]);
    await rules.save(
      const RuleDocument(rules: <RouteRule>[]),
    );

    final summary = await service.import(
      path,
      'pw',
      mode: BackupMerge.merge,
    );

    // t1 restored from backup (wins), local-only survives.
    final tags = endpoints.read().map((e) => e.tag);
    expect(tags, containsAll(<String>['t1', 'local-only']));
    expect(summary.endpoints, 1);
  });

  test('empty password rejected at export', () async {
    await expectLater(
      service.export('${dir.path}/b.qnv', ''),
      throwsArgumentError,
    );
  });

  test('envelope carries magic + version + argon2id params', () async {
    await endpoints.save(<StoredEndpoint>[trojan('t')]);
    final path = '${dir.path}/b.qnv';
    await service.export(path, 'pw');
    final doc = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    expect(doc['magic'], 'YOURVPN-BACKUP');
    expect(doc['version'], 1);
    expect((doc['kdf'] as Map)['algo'], 'argon2id');
    expect((doc['kdf'] as Map)['memoryKiB'], 19456);
    expect(doc['cipher'], 'aes-256-gcm');
  });
}
