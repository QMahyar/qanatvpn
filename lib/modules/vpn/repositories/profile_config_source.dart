import 'dart:convert';

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

  @override
  Future<TypedConfig> resolve(String tag) async {
    Map<String, dynamic> json = _cache ??= await _load();

    final stored = endpointStore?.read() ?? const <StoredEndpoint>[];
    final doc = policyStore?.read();
    final groups = doc?.groups ?? const <OutboundGroup>[];
    final userRules = ruleStore?.read().rules ?? const <RouteRule>[];

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

    final split = splitStore?.read();
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

  /// Inserts stored endpoint outbounds + group outbounds ahead of the
  /// envelope selector and prepends their tags to the selector's member
  /// list. Group policies with errors other than unknown-endpoint-members
  /// never reach the engine — the same validation errors show in the editor
  /// and the unmodified profile ships instead.
  static Map<String, dynamic> _merged(
    Map<String, dynamic> profile,
    List<OutboundGroup> groups,
    List<String> declaredLeaves,
    List<StoredEndpoint> stored,
  ) {
    final endpointTags = <String>[for (final item in stored) item.tag];
    final errors = const RoutingCompiler()
        .compile(
          RoutingPolicy(
            rules: const <RouteRule>[],
            groups: groups,
            leafOutbounds: <String>[...declaredLeaves, ...endpointTags],
          ),
        )
        .validationErrors;
    if (errors.isNotEmpty) {
      return profile;
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
    final patched = <String, dynamic>{...profile};
    final outbounds = <dynamic>[
      ...endpointOutbounds,
      for (final group in groups) _groupJson(group),
      ...(profile['outbounds'] as List<dynamic>? ?? const <dynamic>[]),
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
      final selector = outbounds[selectorIndex] as Map<String, dynamic>;
      selector['outbounds'] = <String>[
        for (final group in groups) group.tag,
        ...endpointOutbounds.map((o) => o['tag'] as String),
        ...((selector['outbounds'] as List<dynamic>? ?? const <dynamic>[])
            .cast<String>()),
      ];
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
    final String raw = await rootBundle.loadString(assetPath);
    final dynamic decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('profile at $assetPath is not a JSON object');
    }
    return decoded;
  }
}
