/// The key/value store outside the browser. In a desktop build (macOS,
/// Windows, Linux) every key is a file in the app's support folder, so the
/// preferences, the autosaved projects, their versions and the recovery
/// survive a restart, as localStorage keeps them on the web. Under
/// `flutter test` and in plain Dart (tools, the command line) it stays in
/// memory.
library;

import 'dart:convert';
import 'dart:io';

String? getPref(String key) => _store.get(key);
void setPref(String key, String value) => _store.set(key, value);
void removePref(String key) => _store.remove(key);

/// The keys of this run and their values (tests compare them before and after).
Map<String, String> debugPrefs() => _store.snapshot();

final PrefsStore _store = _platformStore();

PrefsStore _platformStore() {
  // dart:ui is there in a Flutter app and not in plain Dart; the tests set FLUTTER_TEST
  if (!const bool.fromEnvironment('dart.library.ui') || Platform.environment['FLUTTER_TEST'] == 'true') return PrefsStore.memory();
  final dir = desktopPrefsFolder(Platform.environment);
  return dir == null ? PrefsStore.memory() : PrefsStore.files(Directory(dir));
}

/// Where a desktop build keeps its preferences: the per-user application
/// support folder of the system, or null when the environment does not say.
String? desktopPrefsFolder(Map<String, String> env, {String? os}) {
  final system = os ?? Platform.operatingSystem;
  String? nonEmpty(String? s) => s == null || s.isEmpty ? null : s;
  final home = nonEmpty(env['HOME']);
  switch (system) {
    case 'macos':
      return home == null ? null : '$home/Library/Application Support/OpenCADIrrigation/prefs';
    case 'windows':
      final appData = nonEmpty(env['APPDATA']);
      return appData == null ? null : '$appData\\OpenCADIrrigation\\prefs';
    case 'linux':
      final config = nonEmpty(env['XDG_CONFIG_HOME']) ?? (home == null ? null : '$home/.config');
      return config == null ? null : '$config/opencadirrigation/prefs';
  }
  return null;
}

/// Keys and values in memory, written through to one file per key in
/// [folder] when there is one (written to a temporary file and renamed, so
/// that a crash never leaves half a value). A folder that cannot be written
/// leaves the store working in memory.
class PrefsStore {
  PrefsStore.memory() : folder = null;
  PrefsStore.files(Directory this.folder);

  final Directory? folder;
  final Map<String, String?> _cache = {};

  /// The file of [key]: its UTF-8 bytes in base64url (any key makes a valid
  /// file name on every system, and the files never clash).
  File fileOf(String key) => File('${folder!.path}${Platform.pathSeparator}${base64Url.encode(utf8.encode(key)).replaceAll('=', '')}.txt');

  String? get(String key) {
    if (_cache.containsKey(key) || folder == null) return _cache[key];
    String? value;
    try {
      final f = fileOf(key);
      if (f.existsSync()) value = f.readAsStringSync();
    } on Object {
      // unreadable: as if absent
    }
    return _cache[key] = value;
  }

  void set(String key, String value) {
    _cache[key] = value;
    if (folder == null) return;
    try {
      folder!.createSync(recursive: true);
      final f = fileOf(key);
      final tmp = File('${f.path}.tmp')..writeAsStringSync(value, flush: true);
      tmp.renameSync(f.path);
    } on Object {
      // read-only or full disk: kept for this session only
    }
  }

  /// The keys read or written in this run that have a value (a store kept
  /// in files does not list its folder).
  Map<String, String> snapshot() => {
    for (final e in _cache.entries)
      if (e.value != null) e.key: e.value!,
  };

  void remove(String key) {
    if (folder == null) {
      _cache.remove(key);
      return;
    }
    _cache[key] = null;
    try {
      final f = fileOf(key);
      if (f.existsSync()) f.deleteSync();
    } on Object {
      // already gone, or not ours to delete
    }
  }
}
