/// Typed routing policy model for the 30-field sing-box route rule editor.
///
/// Fields mirror `route.rules` option names in amnezia-box; the compiler owns
/// the mapping to JSON so no caller ever writes a raw field name.
class RoutingPolicy {
  const RoutingPolicy({
    required this.rules,
    this.defaultOutbound = 'PROXY',
    this.groups = const <OutboundGroup>[],
    this.leafOutbounds = const <String>[],
    this.torChain,
  });

  final List<RouteRule> rules;

  /// Outbound for traffic no rule matched.
  final String defaultOutbound;

  /// Outbound groups (selector/urltest) the compiler emits ahead of the
  /// envelope's selector. 3-tier convention: `auto` urltest members reference
  /// [leafOutbounds], the envelope `PROXY` selector includes every group.
  final List<OutboundGroup> groups;

  /// Endpoint/leaf tags visible to group members (e.g. `awg-hkg-02`).
  final List<String> leafOutbounds;

  /// When set, the compiler emits the Tor SOCKS sidecar outbound and
  /// references to `TOR-CHAIN` become valid. The endpoint itself gets the
  /// `detour` injected by the assembler (engine-gated by TorAdapter).
  final TorChainOptions? torChain;
}

/// Group outbound: user-facing selector or latency-measuring urltest.
class OutboundGroup {
  const OutboundGroup.selector({
    required this.tag,
    required this.members,
    this.defaultMember,
    this.interruptExistConnections = false,
  }) : isUrlTest = false,
       url = null,
       interval = null,
       tolerance = null,
       idleTimeout = null;

  const OutboundGroup.urlTest({
    required this.tag,
    required this.members,
    this.url = 'https://www.gstatic.com/generate_204',
    this.interval = const Duration(minutes: 5),
    this.tolerance = 50,
    this.idleTimeout,
    this.interruptExistConnections = false,
  }) : isUrlTest = true,
       defaultMember = null;

  final String tag;
  final List<String> members;
  final bool isUrlTest;

  /// Selector-only: member chosen when no explicit selection was made.
  final String? defaultMember;
  final bool interruptExistConnections;

  /// Urltest-only: probe URL, measure interval, failover tolerance (ms).
  final String? url;
  final Duration? interval;
  final int? tolerance;

  /// Urltest-only (audit W4.7, engine-probed on 1.14): connections to a
  /// node that lost best-status are killed after this idle window instead
  /// of living to their natural end. Null = engine default.
  final Duration? idleTimeout;
}

/// The Tor SOCKS sidecar seam: a local `socks` outbound the chain dials
/// through. Never `type: tor` inside sing-box (no such outbound upstream,
/// entry-block FATALs the whole box — #4200).
class TorChainOptions {
  const TorChainOptions({
    this.host = '127.0.0.1',
    this.port = 9050,
    this.tag = 'tor-entry',
  });

  final String host;
  final int port;
  final String tag;
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
    this.portRanges,
    this.sourcePortRanges,
    this.networks,
    this.protocols,
    this.ipVersion,
    this.ipIsPrivate,
    this.sourceIpIsPrivate,
    this.packageNames,
    this.processNames,
    this.processPaths,
    this.processPathRegexes,
    this.userIds,
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

  /// Inclusive `min:max` port spans (`1000:2000`), fork `port_range`.
  final List<String>? portRanges;
  final List<String>? sourcePortRanges;
  final List<String>? networks;
  final List<String>? protocols;

  /// `4` or `6`, fork `ip_version`. Anything else is a validation error.
  final int? ipVersion;

  /// `ip_is_private` / `source_ip_is_private` — match RFC1918/ULA without
  /// listing the CIDRs by hand.
  final bool? ipIsPrivate;
  final bool? sourceIpIsPrivate;

  final List<String>? packageNames;
  final List<String>? processNames;

  /// Full executable path match (Windows/desktop split), fork `process_path`.
  final List<String>? processPaths;
  final List<String>? processPathRegexes;

  /// POSIX uid list, fork `user_id` (int32).
  final List<int>? userIds;

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

  /// True only for a well-formed logical node. The two half-built shapes —
  /// sub-rules with no mode, or a mode with no sub-rules — are NOT logical;
  /// the compiler reports both as validation errors instead of silently
  /// compiling (or dropping) one side.
  bool get isLogical => rules.isNotEmpty && logicalMode != null;

  /// Shape errors for the half-built logical forms. Checked by the compiler
  /// before branching so nested rules are never silently dropped.
  List<String> logicalShapeErrors(String where) {
    final errors = <String>[];
    if (rules.isNotEmpty && logicalMode == null) {
      errors.add(
        '$where: ${rules.length} sub-rule(s) need logicalMode "and"/"or"',
      );
    }
    if (rules.isEmpty && logicalMode != null) {
      errors.add(
        '$where: logicalMode "$logicalMode" needs at least 2 sub-rules',
      );
    }
    return errors;
  }
}

/// Result of [RoutingCompiler.compile]: valid JSON + all validation errors at
/// once (the 30-field editor shows every problem, not the first).
class CompiledRoute {
  const CompiledRoute({
    required this.rulesJson,
    required this.ruleSetTags,
    required this.validationErrors,
    this.outboundsJson = const <Map<String, dynamic>>[],
  });

  /// The `route.rules` array, ready to embed in a sing-box config.
  final List<Map<String, dynamic>> rulesJson;

  /// Group outbound objects (selector/urltest), ordered so members precede
  /// referencers where possible; goes into `outbounds` before the envelope's
  /// selector and DIRECT.
  final List<Map<String, dynamic>> outboundsJson;

  /// Distinct rule-set tags referenced by the compiled rules
  /// (GeoAsset.ensure tag list).
  final List<String> ruleSetTags;

  final List<String> validationErrors;

  bool get isValid => validationErrors.isEmpty;
}
