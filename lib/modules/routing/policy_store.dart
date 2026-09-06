import 'dart:convert';
import 'dart:io';

import '../../core/persistence/atomic_write.dart';
import '../../core/persistence/app_paths.dart';
import 'routing_policy.dart';

/// File-backed outbound-group policy persistence.
class PolicyStore {
  const PolicyStore({this.baseDir});

  final String? baseDir;

  Future<void> save(PolicyDocument doc) async {
    await atomicWriteString(_file(), doc.toJsonString());
  }

  PolicyDocument read() {
    try {
      final file = _file();
      if (!file.existsSync()) {
        return const PolicyDocument.empty();
      }
      return PolicyDocument.fromJsonString(file.readAsStringSync());
    } on Object {
      return const PolicyDocument.empty();
    }
  }

  File _file() => File(
    baseDir != null
        ? '$baseDir/policy.json'
        : '${defaultBaseDirSync()}/.yourvpn/policy.json',
  );
}

/// Serializable {groups, leafOutbounds}.
class PolicyDocument {
  const PolicyDocument({required this.groups, required this.leafOutbounds});

  const PolicyDocument.empty()
    : groups = const <OutboundGroup>[],
      leafOutbounds = const <String>[];

  factory PolicyDocument.fromJsonString(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return PolicyDocument(
        groups: <OutboundGroup>[
          for (final g in json['groups'] as List<dynamic>? ?? const <dynamic>[])
            _groupFromJson(g as Map<String, dynamic>),
        ],
        leafOutbounds: <String>[
          for (final t
              in json['leafOutbounds'] as List<dynamic>? ?? const <dynamic>[])
            t as String,
        ],
      );
    } on Object {
      return const PolicyDocument.empty();
    }
  }

  static OutboundGroup _groupFromJson(Map<String, dynamic> json) {
    final members = <String>[
      for (final m in json['members'] as List<dynamic>? ?? const <dynamic>[])
        m as String,
    ];
    if (json['type'] == 'urltest') {
      return OutboundGroup.urlTest(
        tag: json['tag'] as String? ?? '',
        members: members,
        url: json['url'] as String?,
        interval: Duration(seconds: json['intervalSeconds'] as int? ?? 300),
        tolerance: json['tolerance'] as int?,
      );
    }
    return OutboundGroup.selector(
      tag: json['tag'] as String? ?? '',
      members: members,
      defaultMember: json['defaultMember'] as String?,
      interruptExistConnections:
          json['interruptExistConnections'] as bool? ?? false,
    );
  }

  final List<OutboundGroup> groups;
  final List<String> leafOutbounds;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'groups': <Map<String, dynamic>>[for (final g in groups) _groupToJson(g)],
    'leafOutbounds': leafOutbounds,
  };

  String toJsonString() => jsonEncode(toJson());

  static Map<String, dynamic> _groupToJson(OutboundGroup group) =>
      <String, dynamic>{
        'type': group.isUrlTest ? 'urltest' : 'selector',
        'tag': group.tag,
        'members': group.members,
        if (group.isUrlTest) ...<String, dynamic>{
          'url': group.url,
          'intervalSeconds': group.interval?.inSeconds,
          'tolerance': group.tolerance,
        } else ...<String, dynamic>{
          'defaultMember': group.defaultMember,
          'interruptExistConnections': group.interruptExistConnections,
        },
      };
}
