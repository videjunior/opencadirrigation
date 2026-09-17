/// Local persistence of projects in the browser (autosave, recent projects
/// and version history) on top of the key/value prefs store. Entries are
/// keyed by the project uid; the index lists them newest first.
library;

import 'dart:convert';

import 'prefs.dart';

class StoredProject {
  StoredProject({required this.uid, required this.name, required this.savedAt, required this.kind, required this.bytes, this.version = 0, this.label = ''});
  final String uid;
  final String name;
  final DateTime savedAt;

  /// autosave | saved | version
  final String kind;
  final int bytes;
  final int version;
  final String label;

  Map<String, dynamic> toJson() => {'uid': uid, 'name': name, 'at': savedAt.toIso8601String(), 'kind': kind, 'bytes': bytes, 'v': version, if (label.isNotEmpty) 'label': label};
  static StoredProject fromJson(Map<String, dynamic> j) => StoredProject(uid: j['uid'] as String, name: j['name'] as String? ?? '', savedAt: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(), kind: j['kind'] as String? ?? 'saved', bytes: (j['bytes'] as num?)?.toInt() ?? 0, version: (j['v'] as num?)?.toInt() ?? 0, label: j['label'] as String? ?? '');
}

/// Repository of stored projects (browser storage).
abstract class ProjectRepository {
  List<StoredProject> list();
  String? load(String uid, {int? version});
  void save(String uid, String name, String json, {String kind = 'saved', String label = ''});
  void remove(String uid);
  List<StoredProject> versions(String uid);
}

class LocalProjectStore implements ProjectRepository {
  LocalProjectStore({this.maxProjects = 8, this.maxVersions = 10, this.maxBytes = 3500000});
  final int maxProjects;
  final int maxVersions;

  /// Approximate cap on the bytes kept for one project (localStorage is
  /// usually limited to ~5 MB per origin).
  final int maxBytes;

  static const _index = 'store.index';

  List<StoredProject> _readIndex() {
    final raw = getPref(_index);
    if (raw == null) return [];
    try {
      return ((jsonDecode(raw) as List).cast<Map<String, dynamic>>()).map(StoredProject.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  void _writeIndex(List<StoredProject> idx) {
    idx.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    setPref(_index, jsonEncode(idx.map((e) => e.toJson()).toList()));
  }

  @override
  List<StoredProject> list() => _readIndex().where((e) => e.kind != 'version').toList();

  @override
  List<StoredProject> versions(String uid) => _readIndex().where((e) => e.uid == uid && e.kind == 'version').toList()..sort((a, b) => b.version.compareTo(a.version));

  @override
  String? load(String uid, {int? version}) => getPref(version == null ? 'store.$uid' : 'store.$uid.v$version');

  /// Saves the project. `autosave` overwrites the previous autosave of the
  /// same uid; `saved` also records a version (version history).
  @override
  void save(String uid, String name, String json, {String kind = 'saved', String label = ''}) {
    if (json.length > maxBytes) return; // too large for the browser store
    var idx = _readIndex();
    idx.removeWhere((e) => e.uid == uid && e.kind != 'version');
    var version = 0;
    if (kind == 'saved') {
      final vs = versions(uid);
      version = (vs.isEmpty ? 0 : vs.first.version) + 1;
      _put('store.$uid.v$version', json);
      idx.add(StoredProject(uid: uid, name: name, savedAt: DateTime.now(), kind: 'version', bytes: json.length, version: version, label: label));
      // keep only the last versions
      final all = idx.where((e) => e.uid == uid && e.kind == 'version').toList()..sort((a, b) => b.version.compareTo(a.version));
      for (final old in all.skip(maxVersions)) {
        removePref('store.$uid.v${old.version}');
        idx.remove(old);
      }
    }
    if (!_put('store.$uid', json)) {
      // quota: drop the oldest other projects and retry once
      final others = idx.where((e) => e.uid != uid).toList()..sort((a, b) => a.savedAt.compareTo(b.savedAt));
      for (final o in others.take(2)) {
        _drop(o, idx);
      }
      _put('store.$uid', json);
    }
    idx.add(StoredProject(uid: uid, name: name, savedAt: DateTime.now(), kind: kind, bytes: json.length, version: version));
    // cap the number of projects
    final projects = idx.where((e) => e.kind != 'version').toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    for (final old in projects.skip(maxProjects)) {
      _drop(old, idx);
    }
    _writeIndex(idx);
  }

  void _drop(StoredProject p, List<StoredProject> idx) {
    removePref('store.${p.uid}');
    for (final v in idx.where((e) => e.uid == p.uid && e.kind == 'version').toList()) {
      removePref('store.${p.uid}.v${v.version}');
      idx.remove(v);
    }
    idx.removeWhere((e) => e.uid == p.uid);
  }

  bool _put(String key, String value) {
    setPref(key, value);
    return getPref(key) == value;
  }

  @override
  void remove(String uid) {
    final idx = _readIndex();
    final p = idx.where((e) => e.uid == uid).firstOrNull;
    if (p != null) _drop(p, idx);
    _writeIndex(idx);
  }

  /// Autosaves that were not turned into a normal save (crash recovery).
  List<StoredProject> recoverable() => list().where((e) => e.kind == 'autosave').toList();

  /// Marks an autosave as acknowledged (keeps it as a recent project).
  void acknowledge(String uid) {
    final idx = _readIndex();
    final i = idx.indexWhere((e) => e.uid == uid && e.kind == 'autosave');
    if (i < 0) return;
    final e = idx[i];
    idx[i] = StoredProject(uid: e.uid, name: e.name, savedAt: e.savedAt, kind: 'saved', bytes: e.bytes);
    _writeIndex(idx);
  }

  /// Removes every stored project and version (tests, "clear browser data").
  void clearAll() {
    final idx = _readIndex();
    for (final e in idx) {
      removePref('store.${e.uid}');
      if (e.kind == 'version') removePref('store.${e.uid}.v${e.version}');
    }
    removePref(_index);
  }

  /// Renames the entry (after the project name changes).
  void rename(String uid, String name) {
    final idx = _readIndex();
    for (var i = 0; i < idx.length; i++) {
      final e = idx[i];
      if (e.uid == uid) idx[i] = StoredProject(uid: e.uid, name: name, savedAt: e.savedAt, kind: e.kind, bytes: e.bytes, version: e.version, label: e.label);
    }
    _writeIndex(idx);
  }
}
