import 'dart:convert';
import 'dart:io';

import '../../../core/persistence/atomic_write.dart';
import '../../../core/persistence/app_paths.dart';
import 'ingestion/endpoint_outbound.dart';
import 'ingestion/normalized_endpoint.dart';

/// File-backed stored endpoints: the user's imported endpoint list.
///
/// Every endpoint keeps its parsed [NormalizedEndpoint] (re-serializable via
/// its own toJson) and its generated outbound JSON is recomputed on demand —
/// the stored form never bakes in engine shapes.
class EndpointStore {
  const EndpointStore({this.baseDir});

  final String? baseDir;

  Future<void> save(List<StoredEndpoint> endpoints) async {
    await atomicWriteString(
      _file(),
      jsonEncode(<String, dynamic>{
        'endpoints': <Map<String, dynamic>>[
          for (final e in endpoints) e.toJson(),
        ],
      }),
    );
  }

  List<StoredEndpoint> read() {
    try {
      final file = _file();
      if (!file.existsSync()) {
        return const <StoredEndpoint>[];
      }
      final doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return <StoredEndpoint>[
        for (final raw
            in doc['endpoints'] as List<dynamic>? ?? const <dynamic>[])
          StoredEndpoint.fromJson(raw as Map<String, dynamic>),
      ];
    } on Object {
      return const <StoredEndpoint>[];
    }
  }

  /// Tags the groups editor references: every endpoint's user-facing tag.
  List<String> tags() => read().map((e) => e.endpoint.tag).toSet().toList();

  /// Outbound JSON entries for the 6 proxy protocols. WG/AWG endpoints are
  /// excluded here — they ship via `endpoints[]` from their own config path.
  List<Map<String, dynamic>> outboundJson() => <Map<String, dynamic>>[
    for (final stored in read())
      if (stored.endpoint is! WireGuardEndpoint)
        endpointToOutboundJson(stored.endpoint),
  ];

  File _file() => File(
    baseDir != null
        ? '$baseDir/endpoints.json'
        : '${defaultBaseDirSync()}/.qanatvpn/endpoints.json',
  );
}

/// One stored endpoint: parsed model + display name + import origin.
class StoredEndpoint {
  const StoredEndpoint({
    required this.endpoint,
    required this.label,
    this.sourceUrl,
  });

  factory StoredEndpoint.fromJson(Map<String, dynamic> json) {
    return StoredEndpoint(
      endpoint: normalizedFromJson(json['endpoint'] as Map<String, dynamic>),
      label: json['label'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String?,
    );
  }

  final NormalizedEndpoint endpoint;

  /// Editor-facing name; defaults to the endpoint's tag.
  final String label;
  final String? sourceUrl;

  String get tag => endpoint.tag;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'endpoint': normalizedToJson(endpoint),
    'label': label,
    if (sourceUrl != null) 'sourceUrl': sourceUrl,
  };
}
