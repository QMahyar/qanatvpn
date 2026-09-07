import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../modules/onboarding/split_store.dart';
import '../../modules/routing/policy_store.dart';
import '../../modules/routing/routing_compiler.dart';
import '../../modules/routing/routing_policy.dart';
import '../../modules/routing/rule_store.dart';
import '../../modules/vpn/repositories/endpoint_store.dart';
import '../persistence/atomic_write.dart';

/// Encrypted backup of every user-state store.
///
/// Envelope (JSON): magic + version + Argon2id params + salt + one AES-256-
/// GCM [SecretBox] (nonce, MAC, ciphertext) of the payload JSON. The payload
/// captures the four user-state stores in their API shapes (endpoints,
/// rules, policy, split choice); the update-check file and engine temp
/// configs are device-local state and are excluded by design.
///
/// Secrets posture: the payload is 100% credentials-bearing (WG private
/// keys, preshared keys, every protocol uuid/password — stores keep them
/// plaintext at rest today), so the password is mandatory and the KDF uses
/// OWASP-recommended Argon2id parameters (m=19 MiB, t=2, p=1). A wrong
/// password surfaces as [SecretBoxAuthenticationError] from the AEAD, never
/// as a partial import.
class BackupService {
  BackupService({
    EndpointStore? endpointStore,
    RuleStore? ruleStore,
    PolicyStore? policyStore,
    SplitStore? splitStore,
    Random? random,
  }) : _endpointStore = endpointStore ?? const EndpointStore(),
       _ruleStore = ruleStore ?? const RuleStore(),
       _policyStore = policyStore ?? const PolicyStore(),
       _splitStore = splitStore ?? const SplitStore(),
       _random = random ?? Random.secure();

  static const String magic = 'YOURVPN-BACKUP';
  static const int version = 1;

  /// OWASP Argon2id minimums for interactive authentication.
  static const int kdfMemoryKiB = 19456;
  static const int kdfIterations = 2;
  static const int kdfParallelism = 1;

  final EndpointStore _endpointStore;
  final RuleStore _ruleStore;
  final PolicyStore _policyStore;
  final SplitStore _splitStore;
  final Random _random;

  /// Encrypts current state into [path] (atomic tmp+rename, like the
  /// stores). Returns the written byte count.
  Future<int> export(String path, String password) async {
    final encoded = await exportBytes(password);
    await atomicWriteBytes(File(path), encoded);
    return encoded.length;
  }

  /// Encrypts current state into an envelope byte payload without touching
  /// disk — the file_picker save dialog consumes these bytes directly.
  Future<List<int>> exportBytes(String password) async {
    if (password.isEmpty) {
      throw ArgumentError('backup password must not be empty');
    }
    final payload = <String, dynamic>{
      'formatVersion': version,
      'endpoints': <dynamic>[
        for (final item in _endpointStore.read()) item.toJson(),
      ],
      'rules': _ruleStore.read().toJson(),
      'policy': _policyStore.read().toJson(),
      'split': _splitStore.read()?.toJson(),
    };
    final envelope = await _encrypt(utf8.encode(jsonEncode(payload)), password);
    return utf8.encode(jsonEncode(envelope));
  }

  /// Decrypts [path] and returns the decoded payload for confirmation UI.
  /// Throws [BackupFormatException] on a non-backup or corrupt file,
  /// [SecretBoxAuthenticationError] on a wrong password.
  Future<Map<String, dynamic>> inspect(String path, String password) async {
    final raw = File(path).readAsBytesSync();
    return _decodePayload(await _decryptEnvelope(raw, password));
  }

  /// Applies a backup to the stores.
  ///
  /// [BackupMerge.replace] overwrites every store with the backup content.
  /// [BackupMerge.merge] folds endpoints/groups by tag (backup wins, the
  /// existing endpoint-import precedent), appends rules (positional list,
  /// no key exists), and leaves the single-doc split choice alone. Returns
  /// a summary for the confirmation UI.
  ///
  /// Validation (review hardening): every other write path runs the
  /// compiler before persisting — an authenticated-but-malformed backup
  /// (or one from a newer schema) must not wipe valid local state with
  /// content the engine would FATAL on. Groups compile against the merged
  /// endpoint-tag universe; rules ship through the compiler too.
  Future<BackupSummary> import(
    String path,
    String password, {
    BackupMerge mode = BackupMerge.replace,
  }) async {
    final payload = await inspect(path, password);
    final endpoints = <StoredEndpoint>[
      for (final item
          in payload['endpoints'] as List<dynamic>? ?? const <dynamic>[])
        StoredEndpoint.fromJson(item as Map<String, dynamic>),
    ];
    final policy = PolicyDocument.fromJsonString(
      jsonEncode(payload['policy'] ?? <String, dynamic>{}),
    );
    final rules = RuleDocument.fromJson(
      payload['rules'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
    final splitJson = payload['split'] as Map<String, dynamic>?;

    final endpointTags = <String>[for (final item in endpoints) item.tag];
    final compiler = const RoutingCompiler();
    final groupErrors = compiler
        .compile(
          RoutingPolicy(
            rules: rules.rules,
            groups: policy.groups,
            leafOutbounds: endpointTags,
          ),
        )
        .validationErrors;
    if (groupErrors.isNotEmpty) {
      throw BackupFormatException(
        'backup content failed routing validation: ${groupErrors.join('; ')}',
      );
    }

    switch (mode) {
      case BackupMerge.replace:
        await _endpointStore.save(endpoints);
        await _policyStore.save(policy);
        await _ruleStore.save(rules);
        final split = splitJson == null
            ? null
            : SplitChoice.fromJson(jsonEncode(splitJson));
        if (split != null) {
          await _splitStore.save(split);
        }
      case BackupMerge.merge:
        // Endpoints + groups: fold by tag, backup wins (keep-last matches
        // the existing re-import semantics in EndpointsController).
        final existing = _endpointStore.read();
        final byTag = <String, StoredEndpoint>{
          for (final item in existing) item.tag: item,
          for (final item in endpoints) item.tag: item,
        };
        await _endpointStore.save(byTag.values.toList());
        final existingPolicy = _policyStore.read();
        final groupsByTag = <String, OutboundGroup>{
          for (final group in existingPolicy.groups) group.tag: group,
          for (final group in policy.groups) group.tag: group,
        };
        await _policyStore.save(
          PolicyDocument(
            groups: groupsByTag.values.toList(),
            leafOutbounds: <String>{
              ...existingPolicy.leafOutbounds,
              ...policy.leafOutbounds,
            }.toList(),
          ),
        );
        final existingRules = _ruleStore.read().rules;
        await _ruleStore.save(
          RuleDocument(rules: <RouteRule>[...existingRules, ...rules.rules]),
        );
      // Single-doc split choice: merge mode leaves it alone.
    }
    return BackupSummary(
      endpoints: endpoints.length,
      groups: policy.groups.length,
      rules: rules.rules.length,
    );
  }

  Future<Map<String, dynamic>> _encrypt(
    List<int> bytes,
    String password,
  ) async {
    final salt = Uint8List.fromList(
      List<int>.generate(16, (_) => _random.nextInt(256)),
    );
    final key = await _deriveKey(password, salt);
    // Audit W3.6: the envelope header (magic/version/KDF params) is now
    // bound into the AEAD as associated data — a tampered header (e.g.
    // swapped version or salt) fails authentication instead of decrypting
    // into garbage or downgrading the KDF.
    final aad = _aadFromParams(
      magic: magic,
      version: version,
      kdfMemoryKiB: kdfMemoryKiB,
      kdfIterations: kdfIterations,
      kdfParallelism: kdfParallelism,
      salt: salt,
    );
    final box = await AesGcm.with256bits().encrypt(
      bytes,
      secretKey: key,
      aad: aad,
    );
    return <String, dynamic>{
      'magic': magic,
      'version': version,
      'kdf': <String, dynamic>{
        'algo': 'argon2id',
        'memoryKiB': kdfMemoryKiB,
        'iterations': kdfIterations,
        'parallelism': kdfParallelism,
        'salt': base64Encode(salt),
      },
      'cipher': 'aes-256-gcm',
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'ciphertext': base64Encode(box.cipherText),
    };
  }

  /// Associated-data bytes binding every unauthenticated envelope field:
  /// magic, version, and the full KDF parameter set + salt.
  List<int> _aadFromParams({
    required String magic,
    required int version,
    required int kdfMemoryKiB,
    required int kdfIterations,
    required int kdfParallelism,
    required Uint8List salt,
  }) {
    return utf8.encode(
      '$magic|$version|argon2id|$kdfMemoryKiB|$kdfIterations|'
      '$kdfParallelism|${base64Encode(salt)}',
    );
  }

  Future<List<int>> _decryptEnvelope(List<int> raw, String password) async {
    Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
    } on Object {
      throw const BackupFormatException('not a JSON backup envelope');
    }
    if (envelope['magic'] != magic) {
      throw const BackupFormatException('missing backup magic');
    }
    if (envelope['version'] != version) {
      throw BackupFormatException(
        'unsupported backup version: ${envelope['version']}',
      );
    }
    final kdf = envelope['kdf'] as Map<String, dynamic>;
    final saltBytes = base64Decode(kdf['salt'] as String);
    final key = await _deriveKey(password, saltBytes);
    try {
      return await AesGcm.with256bits().decrypt(
        SecretBox(
          base64Decode(envelope['ciphertext'] as String),
          nonce: base64Decode(envelope['nonce'] as String),
          mac: Mac(base64Decode(envelope['mac'] as String)),
        ),
        secretKey: key,
        aad: _aadFromParams(
          magic: magic,
          version: version,
          kdfMemoryKiB: kdf['memoryKiB'] as int,
          kdfIterations: kdf['iterations'] as int,
          kdfParallelism: kdf['parallelism'] as int,
          salt: saltBytes,
        ),
      );
    } on SecretBoxAuthenticationError {
      rethrow;
    } on Object catch (error) {
      throw BackupFormatException('corrupt backup envelope: $error');
    }
  }

  static Future<SecretKey> _deriveKey(String password, List<int> salt) {
    return Argon2id(
      memory: kdfMemoryKiB,
      parallelism: kdfParallelism,
      iterations: kdfIterations,
      hashLength: 32,
    ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
  }
}

enum BackupMerge { replace, merge }

class BackupSummary {
  const BackupSummary({
    required this.endpoints,
    required this.groups,
    required this.rules,
  });

  final int endpoints;
  final int groups;
  final int rules;
}

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

Map<String, dynamic> _decodePayload(List<int> bytes) {
  final doc = jsonDecode(utf8.decode(bytes));
  if (doc is! Map<String, dynamic>) {
    throw const BackupFormatException('backup payload is not an object');
  }
  return doc;
}
