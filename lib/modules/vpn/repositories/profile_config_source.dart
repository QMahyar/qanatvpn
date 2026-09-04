import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

import '../../../core/services/tunnel.dart';
import '../../onboarding/split_store.dart';
import '../../routing/policy_store.dart';
import '../../routing/routing_compiler.dart';
import '../../routing/routing_policy.dart';
import 'endpoint_store.dart';
import '../../routing/rule_store.dart';
import '../../vpn/amnezia/awg_config.dart' show wireGuardEndpointToJson;
import 'ingestion/endpoint_outbound.dart';
import 'ingestion/normalized_endpoint.dart' show WireGuardEndpoint;

/// Resolves any tag to the vendored sing-box profile.
///
/// MVP: one generated profile (`profiles/config.wg-awg.json`) shipped as an
/// asset. When the groups/repository layer lands, this becomes a per-tag
/// lookup over stored profiles and this class shrinks to a fallback.
///
/// Merges into the loaded profile before the engine sees it:
/// 1. the wizard's per-app split choice (SplitStore) → TypedConfig lists,
/// 2. the groups editor's outbound groups (PolicyStore) → injected into
///    `outbounds` ahead of the envelope selector, whose member list gains
///    the group tags, so the 3-tier chain reaches the engine.
class ProfileConfigSource implements ConfigSource {
  ProfileConfigSource({
    this.assetPath = 'profiles/config.wg-awg.json',
    this.splitStore,
    this.policyStore,
    this.endpointStore,
    this.ruleStore,
  });

  final String assetPath;

  /// Null on desktop profiles without the wizard store.
  final SplitStore? splitStore;

  /// Null when the groups editor is not wired (default profile shape).
  final PolicyStore? policyStore;

  /// Null when the endpoint importer is not wired (vendored profile only).
  final EndpointStore? endpointStore;

  /// Null when the rules editor is not wired (profile rules only).
  final RuleStore? ruleStore;

  Map<String, dynamic>? _cache;

  /// Single in-flight base-profile load: rapid concurrent connects share one
  /// `rootBundle.loadString` instead of each paying asset IO.
  Future<Map<String, dynamic>>? _loading;

  /// Test seam: when set, `_load` returns this instead of the asset bundle.
  @visibleForTesting
  Future<Map<String, dynamic>> Function()? loadForTest;

  /// Fingerprinted merge cache: tag → last inputs + assembled config.
  /// Reconnects with unchanged stores skip 2 compiler passes + list copies.
  final Map<String, _CachedResolve> _resolved = <String, _CachedResolve>{};

  int _cacheHits = 0;
  int _cacheMisses = 0;

  /// `hits/misses` since construction (or last [resetCacheStats]).
  String cacheStats() => 'hits=$_cacheHits misses=$_cacheMisses';

  @visibleForTesting
  void resetCacheStats() {
    _cacheHits = 0;
    _cacheMisses = 0;
    _resolved.clear();
  }

  @override
  Future<TypedConfig> resolve(String tag) async {
    final stored = endpointStore?.read() ?? const <StoredEndpoint>[];
    final doc = policyStore?.read();
    final groups = doc?.groups ?? const <OutboundGroup>[];
    final ruleDoc = ruleStore?.read();
    final userRules = ruleDoc?.rules ?? const <RouteRule>[];
    final split = splitStore?.read();

    final fingerprint = _fingerprint(
      stored,
      doc,
      ruleDoc,
      split?.allowMode,
      split?.packages,
    );
    final hit = _resolved[tag];
    if (hit != null && hit.fingerprint == fingerprint) {
      _cacheHits++;
      return TypedConfig(
        tag: tag,
        json: _deepCopy(hit.json),
        requiresTor: tag.startsWith('TOR-'),
        includePackages: split != null && split.allowMode
            ? split.packages.toList()
            : const <String>[],
        excludePackages: split != null && !split.allowMode
            ? split.packages.toList()
            : const <String>[],
      );
    }
    _cacheMisses++;

    Map<String, dynamic> json = await _sharedLoad();

    if (groups.isNotEmpty || stored.isNotEmpty) {
      // Merges change the config shape — never mutate the cached base.
      json = _merged(
        json,
        groups,
        doc?.leafOutbounds ?? const <String>[],
        stored,
      );
    }
    if (userRules.isNotEmpty) {
      json = _withRules(json, userRules);
    }

    _resolved[tag] = _CachedResolve(fingerprint, _deepCopy(json));
    final include = split != null && split.allowMode
        ? split.packages.toList()
        : const <String>[];
    final exclude = split != null && !split.allowMode
        ? split.packages.toList()
        : const <String>[];
    return TypedConfig(
      tag: tag,
      json: json,
      requiresTor: tag.startsWith('TOR-'),
      includePackages: include,
      excludePackages: exclude,
    );
  }

  Future<Map<String, dynamic>> _sharedLoad() {
    final base = _cache;
    if (base != null) {
      return Future.value(base);
    }
    _loading ??= _load().then((loaded) {
      _cache = loaded;
      return loaded;
    }).whenComplete(() => _loading = null);
    return _loading!;
  }

  /// Cheap structural fingerprint: JSON shapes + lengths. No crypto dep;
  /// collisions only risk a stale config, and every source string is
  /// included verbatim so a collision needs identical content anyway.
  String _fingerprint(
    List<StoredEndpoint> stored,
    PolicyDocument? policy,
    RuleDocument? rules,
    bool? allowMode,
    Set<String>? packages,
  ) {
    final endpoints = json.encode(<dynamic>[
      for (final item in stored) item.toJson(),
    ]);
    final groups = policy?.toJsonString() ?? '';
    final ruleJson = rules == null ? '' : json.encode(rules.toJson());
    final split = '${allowMode ?? '-'}=${(packages ?? const <String>{}).join(',')}';
    return '${endpoints.length}:$endpoints|$groups|$ruleJson|$split';
  }

  static Map<String, dynamic> _deepCopy(Map<String, dynamic> src) =>
      json.decode(json.encode(src)) as Map<String, dynamic>;

  /// Inserts stored endpoint outbounds + group outbounds ahead of the
  /// envelope selector and prepends their tags to the selector's member
  /// list. Invalid groups are skipped per-group (valid ones still ship)
  /// instead of dropping everything; per-group errors surface in the
  /// groups editor through the same compiler.
  static Map<String, dynamic> _merged(
    Map<String, dynamic> profile,
    List<OutboundGroup> groups,
    List<String> declaredLeaves,
    List<StoredEndpoint> stored,
  ) {
    final endpointTags = <String>[for (final item in stored) item.tag];
    final leafUniverse = <String>{...declaredLeaves, ...endpointTags};
    // Per-group validation: keep the valid groups, skip the broken ones.
    // The old all-or-nothing fallback dropped every endpoint + group on a
    // single typo, silently disconnecting the user's whole setup.
    final validGroups = <OutboundGroup>[];
    for (final group in groups) {
      final errors = const RoutingCompiler()
          .compile(
            RoutingPolicy(
              rules: const <RouteRule>[],
              groups: <OutboundGroup>[group],
              leafOutbounds: leafUniverse.toList(),
            ),
          )
          .validationErrors;
      if (errors.isEmpty) {
        validGroups.add(group);
      }
    }
    final endpointOutbounds = <Map<String, dynamic>>[
      for (final item in stored)
        if (item.endpoint is! WireGuardEndpoint)
          endpointToOutboundJson(item.endpoint),
    ];
    final wgEndpoints = <Map<String, dynamic>>[
      for (final item in stored)
        if (item.endpoint is WireGuardEndpoint)
          wireGuardEndpointToJson(item.endpoint as WireGuardEndpoint),
    ];
    // Deep-copy the profile before mutating: the base is cached across
    // connects, and mutating the selector's member list in place appended
    // duplicates on every connect.
    final patched = <String, dynamic>{
      for (final entry in profile.entries)
        entry.key: entry.value is List
            ? List<dynamic>.from(entry.value as List<dynamic>)
            : entry.value is Map
            ? Map<String, dynamic>.from(entry.value as Map<dynamic, dynamic>)
            : entry.value,
    };
    final outbounds = <dynamic>[
      ...endpointOutbounds,
      for (final group in validGroups) _groupJson(group),
      ...(profile['outbounds'] as List<dynamic>? ?? const <dynamic>[]),
    ];
    final wgTags = <String>[
      for (final item in stored)
        if (item.endpoint is WireGuardEndpoint) item.tag,
    ];
    if (wgEndpoints.isNotEmpty) {
      patched['endpoints'] = <dynamic>[
        ...wgEndpoints,
        ...(profile['endpoints'] as List<dynamic>? ?? const <dynamic>[]),
      ];
    }
    final selectorIndex = outbounds.indexWhere(
      (o) => o is Map<String, dynamic> && o['type'] == 'selector',
    );
    if (selectorIndex >= 0) {
      final selector = Map<String, dynamic>.from(
        outbounds[selectorIndex] as Map<String, dynamic>,
      );
      final existing = <String>[
        ...((selector['outbounds'] as List<dynamic>? ?? const <dynamic>[])
            .cast<String>()),
      ];
      final prepended = <String>[
        for (final group in validGroups) group.tag,
        ...endpointOutbounds.map((o) => o['tag'] as String),
        // WG/AWG endpoints ship via `endpoints[]` but must still be
        // selectable — the old code omitted them, leaving the star protocol
        // unreachable from the PROXY selector.
        ...wgTags,
      ];
      final seen = <String>{};
      selector['outbounds'] = <String>[
        for (final tag in <String>[...prepended, ...existing])
          if (seen.add(tag)) tag,
      ];
      outbounds[selectorIndex] = selector;
    }
    patched['outbounds'] = outbounds;
    return patched;
  }

  /// User rules land after the profile's own (firewall-first) rules — the
  /// vendored profile carries hijack-dns + kill-switch ordering that must
  /// stay ahead. Rules referencing unknown rule_sets ship unmodified.
  static Map<String, dynamic> _withRules(
    Map<String, dynamic> profile,
    List<RouteRule> userRules,
  ) {
    final compiled = routingCompilerForRules.compile(
      RoutingPolicy(rules: userRules),
    );
    if (!compiled.isValid) {
      return profile;
    }
    final patched = <String, dynamic>{...profile};
    final route = <String, dynamic>{
      ...(profile['route'] as Map<String, dynamic>? ??
          const <String, dynamic>{}),
    };
    final existing = route['rules'] as List<dynamic>? ?? const <dynamic>[];
    route['rules'] = <dynamic>[...existing, ...compiled.rulesJson];
    patched['route'] = route;
    return patched;
  }

  static Map<String, dynamic> _groupJson(OutboundGroup group) => group.isUrlTest
      ? <String, dynamic>{
          'type': 'urltest',
          'tag': group.tag,
          'outbounds': List<String>.from(group.members),
          if (group.url != null) 'url': group.url,
          if (group.interval != null)
            'interval': _formatDuration(group.interval!),
          if (group.tolerance != null) 'tolerance': group.tolerance,
        }
      : <String, dynamic>{
          'type': 'selector',
          'tag': group.tag,
          'outbounds': List<String>.from(group.members),
          if (group.defaultMember != null) 'default': group.defaultMember,
          if (group.interruptExistConnections)
            'interrupt_exist_connections': true,
        };

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (seconds == 0) {
      return '${minutes}m';
    }
    return '${minutes}m${seconds}s';
  }

  Future<Map<String, dynamic>> _load() async {
    final hook = loadForTest;
    if (hook != null) {
      return hook();
    }
    final String raw = await rootBundle.loadString(assetPath);
    final dynamic decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('profile at $assetPath is not a JSON object');
    }
    return decoded;
  }
}

/// One fingerprinted merge result: inputs hash + assembled config JSON.
class _CachedResolve {
  const _CachedResolve(this.fingerprint, this.json);

  final String fingerprint;
  final Map<String, dynamic> json;
}
