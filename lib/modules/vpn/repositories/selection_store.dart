import 'dart:io';

import '../../../core/persistence/atomic_write.dart';
import '../../../core/persistence/app_paths.dart';

/// Persists the user's endpoint/group selection so the next connect (and
/// the next app launch) uses the server the user actually picked.
/// Audit W2.1: selection was computed, never stored — the UI could not
/// choose a server at all.
class SelectionStore {
  const SelectionStore({this.baseDir});

  final String? baseDir;

  Future<void> save(String tag) => atomicWriteString(_file(), tag);

  /// Null when nothing is selected (or the file is unreadable/corrupt —
  /// an unreadable selection is no selection).
  String? read() {
    try {
      final file = _file();
      if (!file.existsSync()) {
        return null;
      }
      final tag = file.readAsStringSync().trim();
      return tag.isEmpty ? null : tag;
    } on Object {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final file = _file();
      if (file.existsSync()) {
        await file.delete();
      }
    } on Object {
      // Best-effort: a stuck file just means the stale selection is
      // re-validated (and skipped as dead) on the next read.
    }
  }

  File _file() => File(
    baseDir != null
        ? '$baseDir/selected_tag.json'
        : '${defaultBaseDirSync()}/.qanatvpn/selected_tag.json',
  );
}
