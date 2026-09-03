import 'dart:convert';
import 'dart:io';

import 'routing_compiler.dart';
import 'routing_policy.dart';

/// File-backed routing rules for the Rules tab. Stored as the typed
/// [RouteRule] JSON (same field names as the editor), compiled to engine
/// JSON by the config source.
class RuleStore {
  const RuleStore({this.baseDir});

  final String? baseDir;

  Future<void> save(RuleDocument doc) async {
    final file = _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(doc.toJson()));
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
        : '${Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? Directory.systemTemp.path}'
              '/.yourvpn/rules.json',
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

  static RouteRule _ruleFromJson(Map<String, dynamic> json) {
    return RouteRule(
      outbound: json['outbound'] as String?,
      domains: _strings(json['domains']),
      domainSuffixes: _strings(json['domainSuffixes']),
      domainKeywords: _strings(json['domainKeywords']),
      ipCidrs: _strings(json['ipCidrs']),
      ports: _strings(json['ports']),
      portRanges: _strings(json['portRanges']),
      networks: _strings(json['networks']),
      processNames: _strings(json['processNames']),
      ruleSets: _strings(json['ruleSets']),
      clashMode: json['clashMode'] as String?,
      logicalMode: json['logicalMode'] as String?,
      invert: json['invert'] as bool? ?? false,
    );
  }

  static List<String>? _strings(Object? raw) {
    if (raw == null) {
      return null;
    }
    return <String>[for (final s in raw as List<dynamic>) s as String];
  }

  final List<RouteRule> rules;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'rules': <Map<String, dynamic>>[
      for (final rule in rules) _ruleToJson(rule),
    ],
  };

  static Map<String, dynamic> _ruleToJson(RouteRule rule) => <String, dynamic>{
    'outbound': rule.outbound,
    if (rule.domains != null) 'domains': rule.domains,
    if (rule.domainSuffixes != null) 'domainSuffixes': rule.domainSuffixes,
    if (rule.domainKeywords != null) 'domainKeywords': rule.domainKeywords,
    if (rule.ipCidrs != null) 'ipCidrs': rule.ipCidrs,
    if (rule.ports != null) 'ports': rule.ports,
    if (rule.portRanges != null) 'portRanges': rule.portRanges,
    if (rule.networks != null) 'networks': rule.networks,
    if (rule.processNames != null) 'processNames': rule.processNames,
    if (rule.ruleSets != null) 'ruleSets': rule.ruleSets,
    if (rule.clashMode != null) 'clashMode': rule.clashMode,
    if (rule.logicalMode != null) 'logicalMode': rule.logicalMode,
    if (rule.invert) 'invert': true,
  };
}

/// Compile gate used by both the editor (validation surface) and the config
/// source (merge). One instance, stateless.
const routingCompilerForRules = RoutingCompiler();
