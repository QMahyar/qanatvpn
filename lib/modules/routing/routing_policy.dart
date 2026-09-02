/// Typed routing policy model for the 30-field sing-box route rule editor.
///
/// Fields mirror `route.rules` option names in amnezia-box; the compiler owns
/// the mapping to JSON so no caller ever writes a raw field name.
class RoutingPolicy {
  const RoutingPolicy({required this.rules, this.defaultOutbound = 'PROXY'});

  final List<RouteRule> rules;

  /// Outbound for traffic no rule matched.
  final String defaultOutbound;
}

class RouteRule {
  const RouteRule({
    this.outbound,
    this.domains,
    this.domainSuffixes,
    this.domainKeywords,
    this.domainRegex,
    this.geosite,
    this.geoip,
    this.ipCidrs,
    this.sourceIpCidrs,
    this.ports,
    this.sourcePorts,
    this.networks,
    this.protocols,
    this.packageNames,
    this.processNames,
    this.wifiSsids,
    this.wifiBssids,
    this.users,
    this.inbounds,
    this.clashMode,
    this.ruleSets,
    this.logicalMode,
    this.rules = const <RouteRule>[],
    this.invert = false,
  });

  /// Tag the matched traffic goes to. Required on top-level rules and
  /// logical parents; sub-rules must not set it. `BLOCK` compiles to the
  /// sing-box reject action.
  final String? outbound;

  final List<String>? domains;
  final List<String>? domainSuffixes;
  final List<String>? domainKeywords;
  final List<String>? domainRegex;
  final List<String>? geosite;
  final List<String>? geoip;
  final List<String>? ipCidrs;
  final List<String>? sourceIpCidrs;
  final List<String>? ports;
  final List<String>? sourcePorts;
  final List<String>? networks;
  final List<String>? protocols;
  final List<String>? packageNames;
  final List<String>? processNames;
  final List<String>? wifiSsids;
  final List<String>? wifiBssids;
  final List<String>? users;
  final List<String>? inbounds;
  final String? clashMode;

  /// Tag of a compiled rule-set (GeoAsset registry key, e.g. `geosite-cn`).
  final List<String>? ruleSets;

  /// `and` / `or` — only meaningful when [rules] is non-empty.
  final String? logicalMode;
  final List<RouteRule> rules;
  final bool invert;

  bool get isLogical => rules.isNotEmpty && logicalMode != null;
}

/// Result of [RoutingCompiler.compile]: valid JSON + all validation errors at
/// once (the 30-field editor shows every problem, not the first).
class CompiledRoute {
  const CompiledRoute({
    required this.rulesJson,
    required this.ruleSetTags,
    required this.validationErrors,
  });

  /// The `route.rules` array, ready to embed in a sing-box config.
  final List<Map<String, dynamic>> rulesJson;

  /// Distinct rule-set tags referenced by the compiled rules
  /// (GeoAsset.ensure tag list).
  final List<String> ruleSetTags;

  final List<String> validationErrors;

  bool get isValid => validationErrors.isEmpty;
}
