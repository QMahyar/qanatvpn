import 'dart:convert';
import 'dart:io';

import '../../core/persistence/atomic_write.dart';
import '../../core/persistence/app_paths.dart';

/// The user's per-app split decision from the wizard step 3.
class SplitChoice {
  const SplitChoice({required this.allowMode, required this.packages});

  /// true = only [packages] go through the tunnel (includePackage);
  /// false = [packages] bypass the tunnel (excludePackage).
  final bool allowMode;
  final Set<String> packages;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'allowMode': allowMode,
    'packages': packages.toList(),
  };

  static SplitChoice? fromJson(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      return SplitChoice(
        allowMode: doc['allowMode'] as bool? ?? true,
        packages: <String>{
          for (final p in doc['packages'] as List<dynamic>? ?? const [])
            p as String,
        },
      );
    } on Object {
      return null;
    }
  }
}

/// File-backed persistence so the choice survives restarts and the config
/// source can apply it on every connect. Same store pattern as UpdateStore.
class SplitStore {
  const SplitStore({this.baseDir});

  final String? baseDir;

  Future<void> save(SplitChoice choice) async {
    await atomicWriteString(_file(), jsonEncode(choice.toJson()));
  }

  SplitChoice? read() => SplitChoice.fromJson(_readRaw());

  Future<void> clear() async {
    final file = _file();
    if (file.existsSync()) {
      await file.delete();
    }
  }

  String? _readRaw() {
    try {
      final file = _file();
      if (!file.existsSync()) {
        return null;
      }
      return file.readAsStringSync();
    } on Object {
      return null;
    }
  }

  File _file() => File(
    baseDir != null
        ? '$baseDir/split_choice.json'
        : '${defaultBaseDirSync()}/.yourvpn/split_choice.json',
  );
}
