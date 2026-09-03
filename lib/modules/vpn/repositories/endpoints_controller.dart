import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/plain_fetch.dart';
import 'endpoint_store.dart';
import 'ingestion/ingestion_adapter.dart';

export 'endpoint_store.dart' show StoredEndpoint;

/// HTTP failure surfaced from URL imports (distinct from parse failures).
class UrlFetchException implements Exception {
  const UrlFetchException(this.message);

  final String message;

  @override
  String toString() => message;
}

final endpointStoreProvider = Provider<EndpointStore>(
  (ref) => const EndpointStore(),
);

final ingestionAdapterProvider = Provider<IngestionAdapter>(
  (ref) => IngestionAdapter(),
);

class EndpointsState {
  const EndpointsState({
    this.endpoints = const <StoredEndpoint>[],
    this.error,
    this.importing = false,
  });

  final List<StoredEndpoint> endpoints;
  final String? error;
  final bool importing;

  List<String> get tags => endpoints.map((e) => e.tag).toSet().toList();

  EndpointsState copyWith({
    List<StoredEndpoint>? endpoints,
    String? error,
    bool? importing,
    bool clearError = false,
  }) {
    return EndpointsState(
      endpoints: endpoints ?? this.endpoints,
      error: clearError ? null : (error ?? this.error),
      importing: importing ?? this.importing,
    );
  }
}

/// Import (URI / share-link bundle / clash yaml / sing-box json text) →
/// normalize → persist. Deletions persist immediately. Tags from here feed
/// the groups editor's member universe via PolicyDocument.
class EndpointsController extends Notifier<EndpointsState> {
  @override
  EndpointsState build() {
    return EndpointsState(endpoints: ref.watch(endpointStoreProvider).read());
  }

  /// Ingests raw text pasted by the user. URL-looking text is fetched
  /// (plain fetch, no cache dependency); anything else parses directly.
  Future<void> importText(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(error: 'nothing to import');
      return;
    }
    state = state.copyWith(importing: true, clearError: true);
    try {
      String payload = trimmed;
      var origin = 'pasted';
      final Uri? maybeUrl = Uri.tryParse(trimmed);
      if (maybeUrl != null &&
          (maybeUrl.scheme == 'http' || maybeUrl.scheme == 'https') &&
          maybeUrl.host.isNotEmpty &&
          !trimmed.contains('\n')) {
        final response = await plainFetch(maybeUrl, const <String, String>{
          'Accept': '*/*',
        });
        if (response.statusCode != 200) {
          throw UrlFetchException('HTTP ${response.statusCode} fetching URL');
        }
        payload = utf8.decode(response.body, allowMalformed: true);
        origin = maybeUrl.toString();
      }

      final parsed = ref
          .read(ingestionAdapterProvider)
          .parseAndNormalize(
            RawSubscription(
              bytes: utf8.encode(payload),
              url: Uri.parse(origin),
            ),
          );
      if (parsed.isEmpty) {
        throw const FormatException('no endpoints found in input');
      }

      final store = ref.read(endpointStoreProvider);
      final existing = store.read();
      // Re-importing the same tag replaces the previous entry.
      final mergedTags = existing.map((e) => e.tag).toSet();
      final next =
          <StoredEndpoint>[
                ...existing,
                for (final endpoint in parsed)
                  StoredEndpoint(
                    endpoint: endpoint,
                    label: endpoint.tag,
                    sourceUrl: origin,
                  ),
              ]
              .where((e) {
                // dedupe by tag keeping the last occurrence
                return mergedTags.remove(e.tag) || true;
              })
              .fold<Map<String, StoredEndpoint>>(<String, StoredEndpoint>{}, (
                map,
                e,
              ) {
                map[e.tag] = e;
                return map;
              })
              .values
              .toList();

      await store.save(next);
      state = state.copyWith(endpoints: next, importing: false);
    } on Object catch (error) {
      state = state.copyWith(error: error.toString(), importing: false);
    }
  }

  Future<void> delete(int index) async {
    final store = ref.read(endpointStoreProvider);
    final next = <StoredEndpoint>[...store.read()];
    if (index < 0 || index >= next.length) {
      return;
    }
    next.removeAt(index);
    await store.save(next);
    state = state.copyWith(endpoints: next);
  }
}

final endpointsControllerProvider =
    NotifierProvider<EndpointsController, EndpointsState>(
      EndpointsController.new,
    );
