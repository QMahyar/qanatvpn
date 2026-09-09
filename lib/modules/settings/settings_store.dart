import 'dart:convert';
import 'dart:io';

import '../../core/persistence/atomic_write.dart';
import '../../core/persistence/app_paths.dart';

/// User preferences (audit W2.2 — the app had no settings surface at all).
/// Every field is optional-with-default so new keys never break old files.
class Settings {
  const Settings({
    this.themeMode = 'system',
    this.language = 'system',
    this.autoConnect = false,
    this.reconnectEnabled = true,
  });

  /// 'system' | 'light' | 'dark'
  final String themeMode;

  /// 'system' | 'en' | 'fa'
  final String language;

  /// Connect the last-used endpoint on app launch.
  final bool autoConnect;

  /// Master switch for the auto-reconnect loop (audit W2.4 follow-up).
  final bool reconnectEnabled;

  Settings copyWith({
    String? themeMode,
    String? language,
    bool? autoConnect,
    bool? reconnectEnabled,
  }) {
    return Settings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      autoConnect: autoConnect ?? this.autoConnect,
      reconnectEnabled: reconnectEnabled ?? this.reconnectEnabled,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'themeMode': themeMode,
    'language': language,
    'autoConnect': autoConnect,
    'reconnectEnabled': reconnectEnabled,
  };

  static Settings fromJson(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const Settings();
    }
    try {
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      return Settings(
        themeMode: doc['themeMode'] as String? ?? 'system',
        language: doc['language'] as String? ?? 'system',
        autoConnect: doc['autoConnect'] as bool? ?? false,
        reconnectEnabled: doc['reconnectEnabled'] as bool? ?? true,
      );
    } on Object {
      return const Settings();
    }
  }
}

class SettingsStore {
  const SettingsStore({this.baseDir});

  final String? baseDir;

  Settings read() => Settings.fromJson(_readRaw());

  Future<void> save(Settings settings) async =>
      atomicWriteString(_file(), jsonEncode(settings.toJson()));

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
        ? '$baseDir/settings.json'
        : '${defaultBaseDirSync()}/.qanatvpn/settings.json',
  );
}
