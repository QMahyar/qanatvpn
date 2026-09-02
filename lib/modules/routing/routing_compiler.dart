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
      );
      if (json != null) {
        rulesJson.add(json);
      }
    }

    return CompiledRoute(
      rulesJson: rulesJson,
      ruleSetTags: ruleSetTags.toList(),
      validationErrors: errors,
    );
  }

  Map<String, dynamic>? _compileRule(
    RouteRule rule,
    String where,
    List<String> errors,
    Set<String> ruleSetTags, {
    required bool requireOutbound,
  }) {
    if (rule.isLogical) {
      return _compileLogical(rule, where, errors, ruleSetTags);
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
    addList('network', rule.networks);
    addList('protocol', rule.protocols);
    addList('package_name', rule.packageNames);
    addList('process_name', rule.processNames);
    addList('wifi_ssid', rule.wifiSsids);
    addList('wifi_bssid', rule.wifiBssids);
    addList('user', rule.users);
    addList('inbound', rule.inbounds);
    if (rule.clashMode != null) {
      json['clash_mode'] = rule.clashMode;
    }
    if (rule.ruleSets != null && rule.ruleSets!.isNotEmpty) {
      for (final tag in rule.ruleSets!) {
        if (_validRuleSetTag(tag)) {
          ruleSetTags.add(tag);
        } else {
          errors.add('$where: unknown rule_set "$tag" (not in GeoAsset registry)');
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
  Map<String, dynamic> _compileLogical(
    RouteRule rule,
    String where,
    List<String> errors,
    Set<String> ruleSetTags,
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
