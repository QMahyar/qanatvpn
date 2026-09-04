import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/http_cache.dart' show Fetch;
import 'updater.dart';

/// UI state of the update flow.
sealed class UpdateState {
  const UpdateState();
}

class UpdateIdle extends UpdateState {
  const UpdateIdle({this.lastCheckedAt});

  final DateTime? lastCheckedAt;
}

class UpdateChecking extends UpdateState {
  const UpdateChecking();
}

class UpdateAvailable extends UpdateState {
  const UpdateAvailable(this.info);

  final UpdateInfo info;
}

class UpdateUpToDate extends UpdateState {
  const UpdateUpToDate({required this.localVersion});

  final String localVersion;
}

class UpdateFailed extends UpdateState {
  const UpdateFailed(this.message);

  final String message;
}

final updateStoreProvider = Provider<UpdateStore>((ref) => const UpdateStore());

/// Overridable fetch + platform key so tests exercise the full
/// check-now path without touching the network or the platform channel.
final updateFetchProvider = Provider<Fetch>((ref) => plainFetch);

final updatePlatformKeyProvider = Provider<String>((ref) {
  try {
    return resolvePlatformKey();
  } on UnsupportedError {
    return 'android-arm64';
  }
});

/// Loads the stored result at startup and refreshes it on demand. The daily
/// background task writes the same store, so a fresh install shows the last
/// check without a network round trip.
class UpdateController extends Notifier<UpdateState> {
  @override
  UpdateState build() {
    final store = ref.watch(updateStoreProvider);
    final stored = store.read();
    if (stored != null && stored.assetUrl.isNotEmpty) {
      return UpdateAvailable(stored);
    }
    return UpdateIdle(lastCheckedAt: store.lastCheckedAt());
  }

  /// Tests: inject a fake fetch without overriding providers.
  @visibleForTesting
  Fetch? fetchForTest;

  Future<void> checkNow({String? localVersion}) async {
    state = const UpdateChecking();
    final store = ref.read(updateStoreProvider);
    try {
      final platformKey = ref.read(updatePlatformKeyProvider);
      final source = UpdateSource(
        fetchImpl: fetchForTest ?? ref.read(updateFetchProvider),
      );
      final info = await source.latestFor(platformKey);
      if (info == null) {
        state = UpdateUpToDate(localVersion: localVersion ?? '');
        return;
      }
      await store.save(info, localVersion ?? '');
      if (info.version == (localVersion ?? '') ||
          localVersion != null && !info.isNewerThan(localVersion)) {
        state = UpdateUpToDate(localVersion: localVersion ?? '');
        return;
      }
      state = UpdateAvailable(info);
    } on Object catch (error) {
      state = UpdateFailed(error.toString());
    }
  }
}

final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);
