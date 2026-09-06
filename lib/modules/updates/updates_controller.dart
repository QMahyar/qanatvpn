import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/network/http_cache.dart' show Fetch;
import '../../core/persistence/app_paths.dart';
import 'update_installer.dart';
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

/// Download+sha256-verify in progress (audit W1.5: install was a browser
/// handoff with no integrity check — the artifact is now fetched locally,
/// verified fail-closed, and only then handed to the platform installer).
class UpdateVerifying extends UpdateState {
  const UpdateVerifying();
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

  /// Downloads the pending artifact, sha256-verifies it fail-closed, and
  /// hands the verified local file to the platform installer. Throws on
  /// any verification failure — the caller surfaces the message.
  Future<File> installVerified() async {
    final stored = ref.read(updateStoreProvider).readStored()
        ?? (switch (state) {
          UpdateAvailable(:final info) => StoredUpdate(info: info, localVersion: ''),
          _ => null,
        });
    if (stored == null || stored.info.assetUrl.isEmpty) {
      throw const VerifyException('no update available to install');
    }
    state = const UpdateVerifying();
    try {
      final verifier = UpdateVerifier(fetchImpl: fetchForTest ?? ref.read(updateFetchProvider));
      final tempDir = await resolveTempDir();
      final file = await verifier.downloadVerified(
        Uri.parse(stored.info.assetUrl),
        stored.info.sha256,
        digestResolver: () async => stored.info.sha256 ??
            await verifier.siblingDigest(Uri.parse(stored.info.assetUrl)) ??
            (throw const VerifyException('no sha256 digest available — install refused')),
        targetDir: tempDir,
      );      await _handToInstaller(file);
      // Install handed off: the flow is done from our side.
      state = UpdateAvailable(stored.info);
      return file;
    } on Object {
      state = UpdateAvailable(stored.info);
      rethrow;
    }
  }

  Future<void> _handToInstaller(File file) async {
    if (Platform.isAndroid) {
      // Local file + FileProvider ACTION_VIEW application/apk: the install
      // happens from the verified blob, never a re-downloaded URL.
      await const MethodChannel(
        'vpn_service',
      ).invokeMethod<void>('installUpdate', {'path': file.path});
    } else if (Platform.isWindows) {
      // Portable zip: reveal the verified artifact in Explorer (no browser
      // handoff, no OS re-download). /select takes path in the same arg.
      await Process.start('explorer', <String>['/select,${file.path}']);
    } else {
      throw UnsupportedError('no installer for ${Platform.operatingSystem}');
    }
  }
}

final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);
