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
      if (torChain != null) 'TOR-CHAIN',
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
    addList('domain_regex', rule.domainRegex);
    // geosite/geoip rule fields were REMOVED in sing-box 1.12 — compile them
    // to rule_set tags (geosite-cn style) instead of emitting FATAL fields.
    for (final g in rule.geosite ?? const <String>[]) {
      final tag = g.startsWith('geosite-') ? g : 'geosite-$g';
      (json['rule_set'] as List<String>? ?? <String>[]).isEmpty
          ? json['rule_set'] = <String>[tag]
          : (json['rule_set'] as List<String>).add(tag);
      ruleSetTags.add(tag);
    }
    for (final g in rule.geoip ?? const <String>[]) {
      final tag = g.startsWith('geoip-') ? g : 'geoip-$g';
      json['rule_set'] == null
          ? json['rule_set'] = <String>[tag]
          : (json['rule_set'] as List<String>).add(tag);
      ruleSetTags.add(tag);
    }
    addList('ip_cidr', rule.ipCidrs);
    addList('source_ip_cidr', rule.sourceIpCidrs);
    // Fork expects uint16 lists, not strings.
    final ports = rule.ports?.map(int.tryParse).toList();
    if (ports != null && ports.isNotEmpty && ports.every((p) => p != null)) {
      json['port'] = ports.cast<int>();
    } else if (rule.ports != null && rule.ports!.isNotEmpty) {
      errors.add('$where: port values must be integers 0-65535');
    }
    final sourcePorts = rule.sourcePorts?.map(int.tryParse).toList();
    if (sourcePorts != null &&
        sourcePorts.isNotEmpty &&
        sourcePorts.every((p) => p != null)) {
      json['source_port'] = sourcePorts.cast<int>();
    } else if (rule.sourcePorts != null && rule.sourcePorts!.isNotEmpty) {
      errors.add('$where: source_port values must be integers 0-65535');
    }
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
    addList('network', rule.networks);
    addList('protocol', rule.protocols);
    addList('package_name', rule.packageNames);
    addList('process_name', rule.processNames);
    addList('process_path', rule.processPaths);
    addList('process_path_regex', rule.processPathRegexes);
    if (rule.userIds != null && rule.userIds!.isNotEmpty) {
      json['user_id'] = List<int>.from(rule.userIds!);
    }
    addList('wifi_ssid', rule.wifiSsids);
    addList('wifi_bssid', rule.wifiBssids);
    addList('user', rule.users);
    addList('inbound', rule.inbounds);
    if (rule.clashMode != null) {
      json['clash_mode'] = rule.clashMode;
    }
    if (rule.outbound == 'TOR-CHAIN' && policy.torChain == null) {
      errors.add(
        '$where: TOR-CHAIN referenced but RoutingPolicy.torChain is unset',
      );
    }
    if (rule.ruleSets != null && rule.ruleSets!.isNotEmpty) {
      for (final tag in rule.ruleSets!) {
        if (_validRuleSetTag(tag)) {
          ruleSetTags.add(tag);
        } else {
          errors.add(
            '$where: unknown rule_set "$tag" (not in GeoAsset registry)',
          );
        }
      }
      json['rule_set'] = List<String>.from(rule.ruleSets!);
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

  /// Tags must match the GeoAsset registry (todo:4): `geosite-*` / `geoip-*`.
  bool _validRuleSetTag(String tag) {
    return tag.startsWith('geosite-') || tag.startsWith('geoip-');
  }
}
