import 'dart:convert';
import 'dart:io';

import '../../core/persistence/atomic_write.dart';
import '../../core/persistence/app_paths.dart';
import 'routing_compiler.dart';
import 'routing_policy.dart';

/// File-backed routing rules for the Rules tab. Stored as the typed
/// [RouteRule] JSON (same field names as the editor), compiled to engine
/// JSON by the config source.
class RuleStore {
  const RuleStore({this.baseDir});

  final String? baseDir;

  Future<void> save(RuleDocument doc) async {
    await atomicWriteString(_file(), jsonEncode(doc.toJson()));
  }

  RuleDocument read() {
    try {
      final file = _file();
      if (!file.existsSync()) {
        return const RuleDocument.empty();
      }
      return RuleDocument.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );
    } on Object {
      return const RuleDocument.empty();
    }
  }

  File _file() => File(
    baseDir != null
        ? '$baseDir/rules.json'
        : '${defaultBaseDirSync()}/.yourvpn/rules.json',
  );
}

class RuleDocument {
  const RuleDocument({required this.rules});

  const RuleDocument.empty() : rules = const <RouteRule>[];

  factory RuleDocument.fromJson(Map<String, dynamic> json) {
    try {
      return RuleDocument(
        rules: <RouteRule>[
          for (final r in json['rules'] as List<dynamic>? ?? const <dynamic>[])
            _ruleFromJson(r as Map<String, dynamic>),
        ],
      );
    } on Object {
      return const RuleDocument.empty();
    }
  }

  /// Schema version for forward migration: v2 stores all 30 fields +
  /// nested logical sub-rules. v1 files (13 fields, no `version`) load
  /// with the old field subset and save back as v2.
  static const int schemaVersion = 2;

  static RouteRule _ruleFromJson(Map<String, dynamic> json) {
    return RouteRule(
      outbound: json['outbound'] as String?,
      domains: _strings(json['domains']),
      domainSuffixes: _strings(json['domainSuffixes']),
      domainKeywords: _strings(json['domainKeywords']),
      domainRegex: _strings(json['domainRegex']),
      geosite: _strings(json['geosite']),
      geoip: _strings(json['geoip']),
      ipCidrs: _strings(json['ipCidrs']),
      sourceIpCidrs: _strings(json['sourceIpCidrs']),
      ports: _strings(json['ports']),
      sourcePorts: _strings(json['sourcePorts']),
      portRanges: _strings(json['portRanges']),
      sourcePortRanges: _strings(json['sourcePortRanges']),
      networks: _strings(json['networks']),
      protocols: _strings(json['protocols']),
      ipVersion: (json['ipVersion'] as num?)?.toInt(),
      ipIsPrivate: json['ipIsPrivate'] as bool?,
      sourceIpIsPrivate: json['sourceIpIsPrivate'] as bool?,
      packageNames: _strings(json['packageNames']),
      processNames: _strings(json['processNames']),
      processPaths: _strings(json['processPaths']),
      processPathRegexes: _strings(json['processPathRegexes']),
      userIds: _ints(json['userIds']),
      wifiSsids: _strings(json['wifiSsids']),
      wifiBssids: _strings(json['wifiBssids']),
      users: _strings(json['users']),
      inbounds: _strings(json['inbounds']),
      ruleSets: _strings(json['ruleSets']),
      clashMode: json['clashMode'] as String?,
      logicalMode: json['logicalMode'] as String?,
      rules: <RouteRule>[
        for (final r in json['rules'] as List<dynamic>? ?? const <dynamic>[])
          _ruleFromJson(r as Map<String, dynamic>),
      ],
      invert: json['invert'] as bool? ?? false,
    );
  }

  static List<String>? _strings(Object? raw) {
    if (raw == null) {
      return null;
    }
    return <String>[for (final s in raw as List<dynamic>) s as String];
  }

  static List<int>? _ints(Object? raw) {
    if (raw == null) {
      return null;
    }
    return <int>[for (final s in raw as List<dynamic>) (s as num).toInt()];
  }

  final List<RouteRule> rules;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': schemaVersion,
    'rules': <Map<String, dynamic>>[
      for (final rule in rules) _ruleToJson(rule),
    ],
  };

  static Map<String, dynamic> _ruleToJson(RouteRule rule) => <String, dynamic>{
    'outbound': rule.outbound,
    if (rule.domains != null) 'domains': rule.domains,
    if (rule.domainSuffixes != null) 'domainSuffixes': rule.domainSuffixes,
    if (rule.domainKeywords != null) 'domainKeywords': rule.domainKeywords,
    if (rule.domainRegex != null) 'domainRegex': rule.domainRegex,
    if (rule.geosite != null) 'geosite': rule.geosite,
    if (rule.geoip != null) 'geoip': rule.geoip,
    if (rule.ipCidrs != null) 'ipCidrs': rule.ipCidrs,
    if (rule.sourceIpCidrs != null) 'sourceIpCidrs': rule.sourceIpCidrs,
    if (rule.ports != null) 'ports': rule.ports,
    if (rule.sourcePorts != null) 'sourcePorts': rule.sourcePorts,
    if (rule.portRanges != null) 'portRanges': rule.portRanges,
    if (rule.sourcePortRanges != null)
      'sourcePortRanges': rule.sourcePortRanges,
    if (rule.networks != null) 'networks': rule.networks,
    if (rule.protocols != null) 'protocols': rule.protocols,
    if (rule.ipVersion != null) 'ipVersion': rule.ipVersion,
    if (rule.ipIsPrivate != null) 'ipIsPrivate': rule.ipIsPrivate,
    if (rule.sourceIpIsPrivate != null)
      'sourceIpIsPrivate': rule.sourceIpIsPrivate,
    if (rule.packageNames != null) 'packageNames': rule.packageNames,
    if (rule.processNames != null) 'processNames': rule.processNames,
    if (rule.processPaths != null) 'processPaths': rule.processPaths,
    if (rule.processPathRegexes != null)
      'processPathRegexes': rule.processPathRegexes,
    if (rule.userIds != null) 'userIds': rule.userIds,
    if (rule.wifiSsids != null) 'wifiSsids': rule.wifiSsids,
    if (rule.wifiBssids != null) 'wifiBssids': rule.wifiBssids,
    if (rule.users != null) 'users': rule.users,
    if (rule.inbounds != null) 'inbounds': rule.inbounds,
    if (rule.ruleSets != null) 'ruleSets': rule.ruleSets,
    if (rule.clashMode != null) 'clashMode': rule.clashMode,
    if (rule.logicalMode != null) 'logicalMode': rule.logicalMode,
    if (rule.rules.isNotEmpty)
      'rules': <Map<String, dynamic>>[
        for (final sub in rule.rules) _ruleToJson(sub),
      ],
    if (rule.invert) 'invert': true,
  };
}

/// Compile gate used by both the editor (validation surface) and the config
/// source (merge). One instance, stateless.
const routingCompilerForRules = RoutingCompiler();
