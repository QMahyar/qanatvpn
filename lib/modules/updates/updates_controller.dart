import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

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

/// Fail-closed: an unsupported platform surfaces as [UpdateFailed] with the
/// reason when the user checks, instead of silently downloading an
/// android-arm64 APK on some other OS.
final updatePlatformKeyProvider = Provider<String>((ref) {
  try {
    return resolvePlatformKey();
  } on UnsupportedError catch (error) {
    throw StateError('updates unavailable: ${error.message}');
  }
});

/// Loads the stored result at startup and refreshes it on demand. The daily
/// background task writes the same store, so a fresh install shows the last
/// check without a network round trip.
class UpdateController extends Notifier<UpdateState> {
  @override
  UpdateState build() {
    final store = ref.watch(updateStoreProvider);
    final stored = store.readStored();
    if (stored != null && stored.info.assetUrl.isNotEmpty) {
      // Unknown local version (background task ran before the version was
      // stamped in): the artifact is real, show it rather than a false
      // "up to date".
      if (stored.localVersion.isEmpty || stored.isNewerThanLocal) {
        return UpdateAvailable(stored.info);
      }
      return UpdateUpToDate(localVersion: stored.localVersion);
    }
    return UpdateIdle(lastCheckedAt: store.lastCheckedAt());
  }

  /// Tests: inject a fake fetch without overriding providers.
  @visibleForTesting
  Fetch? fetchForTest;

  /// Tests: pin the local version without the plugin channel. Production
  /// reads package_info_plus inside [checkNow], off the startup path.
  @visibleForTesting
  Future<String> Function()? localVersionLoaderForTest;

  Future<String> _loadLocalVersion() async {
    if (localVersionLoaderForTest != null) {
      return localVersionLoaderForTest!();
    }
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } on Object {
      // Plugin unavailable (tests, plugin init failure): unknown version —
      // the store then keeps an empty localVersion and restart comparison
      // stays conservative.
      return '';
    }
  }

  Future<void> checkNow({String? localVersion}) async {
    state = const UpdateChecking();
    final store = ref.read(updateStoreProvider);
    try {
      final platformKey = ref.read(updatePlatformKeyProvider);
      final local = localVersion ?? await _loadLocalVersion();
      final source = UpdateSource(
        fetchImpl: fetchForTest ?? ref.read(updateFetchProvider),
        mirrorUrl: UpdateSource.defaultMirrorUrl,
      );
      final info = await source.latestFor(platformKey);
      if (info == null) {
        state = UpdateUpToDate(localVersion: local);
        return;
      }
      await store.save(info, local);
      if (local.isNotEmpty && !info.isNewerThan(local)) {
        state = UpdateUpToDate(localVersion: local);
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
