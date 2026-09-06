import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Cross-platform resolution of the app's persistent data directory.
///
/// Audit fix (W1.4): every file-backed store resolved paths via the
/// HOME/USERPROFILE env chain with a `Directory.systemTemp` fallback. On
/// Android both env vars are unset and the temp fallback lands in a private
/// cache dir the store cannot rely on — every default-path store write
/// failed. `path_provider`'s `getApplicationSupportDirectory()` is the
/// platform-correct answer, but it is async while the stores do sync file
/// IO, so the resolved path is cached into a global at startup (main) and
/// background-isolate entry points re-resolve via [resolveAppSupportDir].

/// Sync override set once during startup (before any store use) or by
/// tests. When null, [defaultBaseDirSync] falls back to the legacy env-var
/// chain so plain unit tests (no plugin binding) keep working unchanged.
String? appSupportDirOverride;

/// Legacy layout used by v0.1.0 on desktop: `~/.yourvpn`. Kept as the
/// migration source and as the test fallback — on Android this chain
/// yields systemTemp, which is why the platform resolver exists.
String legacyBaseDirSync() {
  return Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      Directory.systemTemp.path;
}

/// Directory stores write into: the startup-resolved app-support dir when
/// available, else the legacy `~` chain. The `.yourvpn` leaf is kept under
/// both layouts so backup/restore and store code stay layout-agnostic.
String defaultBaseDirSync() {
  final override = appSupportDirOverride;
  if (override != null && override.isNotEmpty) {
    return override;
  }
  return legacyBaseDirSync();
}

/// Async resolution for contexts that never ran main() startup wiring
/// (workmanager background isolate). Prefers the cached override, then
/// path_provider, then the legacy chain; successful resolutions are cached
/// so later sync readers in the same isolate see them.
Future<String> resolveAppSupportDir() async {
  final override = appSupportDirOverride;
  if (override != null && override.isNotEmpty) {
    return override;
  }
  try {
    final dir = await getApplicationSupportDirectory();
    appSupportDirOverride = dir.path;
    return dir.path;
  } on Object {
    // Plugin unavailable (tests, stripped isolates): legacy chain.
    return legacyBaseDirSync();
  }
}

/// Directory for transient downloads (update artifacts): platform temp dir
/// via path_provider so Android's FileProvider cache-path mapping matches;
/// falls back to dart:io systemTemp where the plugin is unavailable.
Future<Directory> resolveTempDir() async {
  try {
    return await getTemporaryDirectory();
  } on Object {
    return Directory.systemTemp;
  }
}

/// One-time migration for desktop installs of v0.1.0 whose stores lived in
/// `~/.yourvpn`: copies every store file into the new support dir when the
/// destination lacks it. Never deletes the legacy dir (rollback safety).
/// Android is a no-op (legacy stores never wrote successfully there).
/// [legacyDir] is a test seam; production passes nothing and migrates the
/// real legacy location.
Future<int> migrateLegacyDotYourVpn({Directory? legacyDir}) async {
  if (appSupportDirOverride == null) {
    await resolveAppSupportDir();
  }
  final from = legacyDir ?? Directory('${legacyBaseDirSync()}/.yourvpn');
  if (!from.existsSync()) {
    return 0;
  }
  final to = Directory('${defaultBaseDirSync()}/.yourvpn');
  var copied = 0;
  try {
    for (final entity in from.listSync()) {
      if (entity is! File) {
        continue;
      }
      final dest = File('${to.path}/${entity.uri.pathSegments.last}');
      if (dest.existsSync()) {
        continue;
      }
      await to.create(recursive: true);
      await entity.copy(dest.path);
      copied += 1;
    }
  } on Object {
    // Best-effort: stores recreate missing files; a failed copy must not
    // block startup.
  }
  return copied;
}
