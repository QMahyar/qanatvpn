import '../geo/geo_asset.dart';
import 'routing_policy.dart';

/// Deep compiler: typed [RoutingPolicy] → validated [CompiledRoute].
///
/// Hides the 30 `route.rules` field names, OR-group AND-logic (sing-box
/// `logical` rules evaluate their sub-rules conjunctively inside one `and` /
/// `or` node), `invert`, and rule-set tag dedup. Field errors accumulate —
/// [CompiledRoute.validationErrors] lists everything at once so the 30-field
/// editor can show every problem in one pass.
class RoutingCompiler {
  const RoutingCompiler();

  CompiledRoute compile(RoutingPolicy policy) {
    final errors = <String>[];
    final rulesJson = <Map<String, dynamic>>[];
    final ruleSetTags = <String>{};

    if (policy.defaultOutbound.isEmpty) {
      errors.add('policy: defaultOutbound is required');
    }

    for (var i = 0; i < policy.rules.length; i++) {
      final json = _compileRule(
        policy.rules[i],
        'rule ${i + 1}',
        errors,
        ruleSetTags,
        requireOutbound: true,
        policy: policy,
      );
      if (json != null) {
        rulesJson.add(json);
      }
    }

    final outboundsJson = _compileGroups(policy, errors);

    return CompiledRoute(
      rulesJson: rulesJson,
      ruleSetTags: ruleSetTags.toList(),
      validationErrors: errors,
      outboundsJson: outboundsJson,
    );
  }

  /// Groups go out in declaration order (members must precede referencers —
  /// sing-box resolves outbound refs by tag at start, not order, but stable
  /// order keeps the generated config readable). Member refs are validated
  /// against groups ∪ leafOutbounds ∪ {DIRECT, TOR-CHAIN?}; every unknown
  /// member is one error, all surfaced at once.
  List<Map<String, dynamic>> _compileGroups(
    RoutingPolicy policy,
    List<String> errors,
  ) {
    final torChain = policy.torChain;
    if (torChain != null) {
      final port = torChain.port;
      if (port <= 0 || port > 65535) {
        errors.add('tor chain: socks port out of range 1-65535: $port');
      }
    }
    final groupTags = <String>{for (final g in policy.groups) g.tag};
    final known = <String>{
      ...groupTags,
      ...policy.leafOutbounds,
      'DIRECT',
      if (torChain != null) ...<String>['TOR-CHAIN', torChain.tag],
    };

    final outbounds = <Map<String, dynamic>>[];
    final seenTags = <String>{};
    for (var i = 0; i < policy.groups.length; i++) {
      final group = policy.groups[i];
      final where = 'group ${i + 1} (${group.tag})';
      if (group.tag.isEmpty) {
        errors.add('$where: tag is required');
        continue;
      }
      if (!seenTags.add(group.tag)) {
        errors.add('$where: duplicate group tag "${group.tag}"');
        continue;
      }
      if (group.members.isEmpty) {
        errors.add('$where: selector/urltest needs at least 1 member');
        continue;
      }
      for (final member in group.members) {
        if (!known.contains(member)) {
          errors.add(
            '$where: member "$member" is not a group, endpoint tag, '
            'DIRECT${torChain != null ? ', TOR-CHAIN' : ''} or declared leaf',
          );
        }
      }
      if (group.isUrlTest) {
        final interval = group.interval;
        if (interval != null && interval.inSeconds <= 0) {
          errors.add('$where: urltest interval must be positive');
        }
        outbounds.add(<String, dynamic>{
          'type': 'urltest',
          'tag': group.tag,
          'outbounds': List<String>.from(group.members),
          if (group.url != null) 'url': group.url,
          if (interval != null) 'interval': _formatDuration(interval),
          if (group.tolerance != null) 'tolerance': group.tolerance,
        });
      } else {
        final defaultMember = group.defaultMember;
        if (defaultMember != null && !known.contains(defaultMember)) {
          errors.add('$where: default "$defaultMember" is not a known member');
        }
        outbounds.add(<String, dynamic>{
          'type': 'selector',
          'tag': group.tag,
          'outbounds': List<String>.from(group.members),
          'default': ?defaultMember,
          if (group.interruptExistConnections)
            'interrupt_exist_connections': true,
        });
      }
    }

    if (torChain != null) {
      outbounds.add(<String, dynamic>{
        'type': 'socks',
        'tag': torChain.tag,
        'server': torChain.host,
        'server_port': torChain.port,
        'version': '5',
      });
    }
    return outbounds;
  }

  String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds;
    if (seconds % 60 == 0) {
      return '${seconds ~/ 60}m';
    }
    return '${seconds}s';
  }

  Map<String, dynamic>? _compileRule(
    RouteRule rule,
    String where,
    List<String> errors,
    Set<String> ruleSetTags, {
    required bool requireOutbound,
    required RoutingPolicy policy,
  }) {
    final shapeErrors = rule.logicalShapeErrors(where);
    if (shapeErrors.isNotEmpty) {
      errors.addAll(shapeErrors);
      return null;
    }
    if (rule.isLogical) {
      return _compileLogical(rule, where, errors, ruleSetTags, policy);
    }
    final json = <String, dynamic>{};

    void addList(String key, List<String>? values) {
      if (values == null || values.isEmpty) {
        return;
      }
      json[key] = List<String>.from(values);
    }

    addList('domain', rule.domains);
    addList('domain_suffix', rule.domainSuffixes);
    addList('domain_keyword', rule.domainKeywords);
    _addRegexList(json, 'domain_regex', rule.domainRegex, where, errors);
    // geosite/geoip rule fields were REMOVED in sing-box 1.12 — compile them
    // to rule_set tags (geosite-cn style) instead of emitting FATAL fields.
    // Derived tags merge with explicit ruleSets below (never overwrite).
    final derivedRuleSets = <String>{
      for (final g in rule.geosite ?? const <String>[])
        g.startsWith('geosite-') ? g : 'geosite-$g',
      for (final g in rule.geoip ?? const <String>[])
        g.startsWith('geoip-') ? g : 'geoip-$g',
    };
    _addCidrs(json, 'ip_cidr', rule.ipCidrs, where, errors);
    _addCidrs(json, 'source_ip_cidr', rule.sourceIpCidrs, where, errors);
    // Fork expects uint16 lists, not strings — and tryParse alone is not
    // enough: 99999/-1 parse fine but FATAL the engine at start.
    _addPorts(json, 'port', rule.ports, where, errors);
    _addPorts(json, 'source_port', rule.sourcePorts, where, errors);
    _addPortRanges(json, 'port_range', rule.portRanges, where, errors);
    _addPortRanges(
      json,
      'source_port_range',
      rule.sourcePortRanges,
      where,
      errors,
    );
    if (rule.ipVersion != null) {
      if (rule.ipVersion == 4 || rule.ipVersion == 6) {
        json['ip_version'] = rule.ipVersion;
      } else {
        errors.add('$where: ip_version must be 4 or 6, got ${rule.ipVersion}');
      }
    }
    if (rule.ipIsPrivate != null) {
      json['ip_is_private'] = rule.ipIsPrivate;
    }
    if (rule.sourceIpIsPrivate != null) {
      json['source_ip_is_private'] = rule.sourceIpIsPrivate;
    }
    _addEnumList(
      json,
      'network',
      rule.networks,
      const <String>{'tcp', 'udp'},
      where,
      errors,
    );
    _addEnumList(
      json,
      'protocol',
      rule.protocols,
      const <String>{'http', 'tls', 'quic', 'dns', 'stun', 'bittorrent'},
      where,
      errors,
    );
    addList('package_name', rule.packageNames);
    addList('process_name', rule.processNames);
    addList('process_path', rule.processPaths);
    _addRegexList(
      json,
      'process_path_regex',
      rule.processPathRegexes,
      where,
      errors,
    );
    if (rule.userIds != null && rule.userIds!.isNotEmpty) {
      json['user_id'] = List<int>.from(rule.userIds!);
    }
    addList('wifi_ssid', rule.wifiSsids);
    addList('wifi_bssid', rule.wifiBssids);
    addList('user', rule.users);
    addList('inbound', rule.inbounds);
    if (rule.clashMode != null) {
      const allowed = <String>{'direct', 'global'};
      if (allowed.contains(rule.clashMode!.toLowerCase())) {
        json['clash_mode'] = rule.clashMode;
      } else {
        errors.add(
          '$where: clash_mode must be Direct or Global, got "${rule.clashMode}"',
        );
      }
    }
    if (rule.outbound == 'TOR-CHAIN' && policy.torChain == null) {
      errors.add(
        '$where: TOR-CHAIN referenced but RoutingPolicy.torChain is unset',
      );
    }
    // Merge derived (geosite/geoip) + explicit tags, deduped. Explicit wins
    // nothing — both filters apply — so overwrite would silently drop geo.
    final mergedRuleSets = <String>{
      ...derivedRuleSets,
      for (final tag in rule.ruleSets ?? const <String>[]) tag,
    };
    if (rule.ruleSets != null) {
      for (final tag in rule.ruleSets!) {
        if (!_validRuleSetTag(tag)) {
          errors.add(
            '$where: unknown rule_set "$tag" (not in GeoAsset registry)',
          );
        }
      }
    }
    for (final tag in derivedRuleSets) {
      if (!_validRuleSetTag(tag)) {
        errors.add(
          '$where: unknown rule_set "$tag" (not in GeoAsset registry)',
        );
      }
    }
    if (mergedRuleSets.isNotEmpty) {
      json['rule_set'] = mergedRuleSets.toList();
      ruleSetTags.addAll(mergedRuleSets);
    }

    if (json.isEmpty) {
      errors.add('$where: no condition fields set');
      return null;
    }

    final outbound = rule.outbound;
    if (requireOutbound && (outbound == null || outbound.isEmpty)) {
      errors.add('$where: outbound is required');
      return null;
    }
    if (!requireOutbound && outbound != null && outbound.isNotEmpty) {
      errors.add('$where: sub-rule must not set outbound');
    }
    if (outbound != null && outbound.isNotEmpty) {
      _checkOutboundRef(outbound, policy, where, errors);
    }

    if (rule.invert) {
      json['invert'] = true;
    }
    if (outbound != null && outbound.isNotEmpty) {
      if (outbound == 'BLOCK') {
        // 1.14-native reject action; no BLOCK outbound tag needed.
        json['action'] = 'reject';
      } else {
        json['outbound'] = outbound;
      }
    }
    return json;
  }

  /// `port_range` / `source_port_range`: inclusive `min:max` spans. Shape
  /// validated here (ints, min<max) so the editor shows bad spans at once.
  void _addPortRanges(
    Map<String, dynamic> json,
    String key,
    List<String>? ranges,
    String where,
    List<String> errors,
  ) {
    if (ranges == null || ranges.isEmpty) {
      return;
    }
    final valid = <String>[];
    for (final range in ranges) {
      final match = RegExp(r'^(\d+):(\d+)$').firstMatch(range);
      final min = match == null ? null : int.tryParse(match.group(1)!);
      final max = match == null ? null : int.tryParse(match.group(2)!);
      if (min == null ||
          max == null ||
          min > 65535 ||
          max > 65535 ||
          min >= max) {
        errors.add('$where: $key must be "min:max" (min<max ≤65535): $range');
        continue;
      }
      valid.add(range);
    }
    if (valid.isNotEmpty) {
      json[key] = valid;
    }
  }

  Map<String, dynamic> _compileLogical(
    RouteRule rule,
    String where,
    List<String> errors,
    Set<String> ruleSetTags,
    RoutingPolicy policy,
  ) {
    final mode = rule.logicalMode!.toLowerCase();
    if (mode != 'and' && mode != 'or') {
      errors.add(
        '$where: logical must be "and" or "or", got "${rule.logicalMode}"',
      );
    }
    if (rule.rules.length < 2) {
      errors.add('$where: logical rule needs at least 2 sub-rules');
    }
    final subs = <Map<String, dynamic>>[];
    for (var i = 0; i < rule.rules.length; i++) {
      final sub = _compileRule(
        rule.rules[i],
        '$where sub-rule ${i + 1}',
        errors,
        ruleSetTags,
        requireOutbound: false,
        policy: policy,
      );
      if (sub != null) {
        subs.add(sub);
      }
    }
    final json = <String, dynamic>{
      'type': 'logical',
      'mode': mode,
      'rules': subs,
    };
    if (rule.invert) {
      json['invert'] = true;
    }
    final outbound = rule.outbound;
    if (outbound != null && outbound.isNotEmpty) {
      if (outbound == 'BLOCK') {
        json['action'] = 'reject';
      } else {
        json['outbound'] = outbound;
      }
    }
    return json;
  }

  /// Tags must exist in the GeoAsset registry — prefix-only checks let
  /// `geosite-foobar` compile to a dangling ref that FATALs sing-box with
  /// unknown-rule_set at start.
  bool _validRuleSetTag(String tag) {
    return GeoAsset.registry.containsKey(tag);
  }

  /// Leaf outbound refs must resolve: group tag, declared leaf, DIRECT,
  /// BLOCK (reject action), or TOR-CHAIN with a torChain. A typo like PROXI
  /// otherwise ships and FATALs the engine at start with no editor warning.
  void _checkOutboundRef(
    String outbound,
    RoutingPolicy policy,
    String where,
    List<String> errors,
  ) {
    if (outbound == 'BLOCK' ||
        outbound == 'DIRECT' ||
        outbound == policy.defaultOutbound) {
      return;
    }
    if (outbound == 'TOR-CHAIN') {
      return; // torChain presence checked separately with a better message.
    }
    if (policy.torChain != null && outbound == policy.torChain!.tag) {
      return; // sidecar tag (default tor-entry) is a valid direct ref.
    }
    final groupTags = <String>{for (final g in policy.groups) g.tag};
    if (groupTags.contains(outbound)) {
      return;
    }
    if (policy.leafOutbounds.contains(outbound)) {
      return;
    }
    errors.add(
      '$where: outbound "$outbound" is not a group, endpoint tag, '
      'DIRECT, BLOCK${policy.torChain != null ? ', TOR-CHAIN' : ''} '
      'or declared leaf',
    );
  }

  void _addPorts(
    Map<String, dynamic> json,
    String key,
    List<String>? values,
    String where,
    List<String> errors,
  ) {
    if (values == null || values.isEmpty) {
      return;
    }
    final parsed = <int>[];
    for (final raw in values) {
      final port = int.tryParse(raw);
      if (port == null || port < 0 || port > 65535) {
        errors.add('$where: $key values must be integers 0-65535: $raw');
        continue;
      }
      parsed.add(port);
    }
    if (parsed.isNotEmpty) {
      json[key] = parsed;
    }
  }

  void _addCidrs(
    Map<String, dynamic> json,
    String key,
    List<String>? values,
    String where,
    List<String> errors,
  ) {
    if (values == null || values.isEmpty) {
      return;
    }
    final valid = <String>[];
    for (final raw in values) {
      if (_looksLikeCidr(raw)) {
        valid.add(raw);
      } else {
        errors.add('$where: $key must be CIDR (e.g. 10.0.0.0/8): $raw');
      }
    }
    if (valid.isNotEmpty) {
      json[key] = valid;
    }
  }

  bool _looksLikeCidr(String raw) {
    final slash = raw.lastIndexOf('/');
    if (slash <= 0 || slash == raw.length - 1) {
      return false;
    }
    final addr = raw.substring(0, slash);
    final prefix = int.tryParse(raw.substring(slash + 1));
    if (prefix == null) {
      return false;
    }
    final isV6 = addr.contains(':');
    if (isV6) {
      if (prefix < 0 || prefix > 128) {
        return false;
      }
      return RegExp(r'^[0-9a-fA-F:.]+$').hasMatch(addr);
    }
    if (prefix < 0 || prefix > 32) {
      return false;
    }
    final parts = addr.split('.');
    if (parts.length != 4) {
      return false;
    }
    for (final part in parts) {
      final octet = int.tryParse(part);
      if (octet == null || octet < 0 || octet > 255) {
        return false;
      }
    }
    return true;
  }

  void _addRegexList(
    Map<String, dynamic> json,
    String key,
    List<String>? values,
    String where,
    List<String> errors,
  ) {
    if (values == null || values.isEmpty) {
      return;
    }
    final valid = <String>[];
    for (final raw in values) {
      try {
        RegExp(raw);
        valid.add(raw);
      } on Object {
        errors.add('$where: $key must be a valid regex: $raw');
      }
    }
    if (valid.isNotEmpty) {
      json[key] = valid;
    }
  }

  void _addEnumList(
    Map<String, dynamic> json,
    String key,
    List<String>? values,
    Set<String> allowed,
    String where,
    List<String> errors,
  ) {
    if (values == null || values.isEmpty) {
      return;
    }
    final valid = <String>[];
    for (final raw in values) {
      if (allowed.contains(raw.toLowerCase())) {
        valid.add(raw);
      } else {
        errors.add(
          '$where: $key must be one of ${allowed.join('/ ')}, got "$raw"',
        );
      }
    }
    if (valid.isNotEmpty) {
      json[key] = valid;
    }
  }
}
