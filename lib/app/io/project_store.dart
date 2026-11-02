/// Local persistence of projects in the browser: the copy of each project
/// (autosave, crash recovery), the recent projects and the version history.
///
/// The index of what is kept (small: names, times, sizes) stays in the
/// key/value prefs (localStorage on the web), read at once by the menus and
/// dialogs. The texts of the projects go to a [BodyStore]: the IndexedDB
/// database of the site in the browser, with the localStorage of before
/// 1.6.0 as the fallback (see body_store.dart). [LocalProjectStore.prepare]
/// moves the texts of an older version out of localStorage at start-up.
///
/// Every write says whether it was kept ([StoreOutcome]). A full storage
/// first makes room by dropping the oldest versions of the same project,
/// then the versions of the other projects, then the other projects that
/// were saved to a file; the copy of a project with changes not saved to a
/// file (a recovery) is never dropped to make room.
///
/// Entries are keyed by the project uid; the index lists them newest first.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:archive/archive.dart';

import 'body_store.dart';
import 'gzip_text.dart';
import 'prefs.dart';
import 'window_locks.dart';

class StoredProject {
  StoredProject({required this.uid, required this.name, required this.savedAt, required this.kind, required this.bytes, this.version = 0, this.label = '', int? stored, this.edited})
    : stored = stored ?? bytes;
  final String uid;
  final String name;
  final DateTime savedAt;

  /// autosave | saved | version
  final String kind;

  /// Characters of the project JSON.
  final int bytes;
  final int version;
  final String label;

  /// Characters of the stored form (compressed when large).
  final int stored;

  /// When the project was last edited, as kept (the copies of two windows
  /// or of a page being closed are compared by it).
  final DateTime? edited;

  /// [edited], else when it was saved.
  DateTime get editedOrSaved => edited ?? savedAt;

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'name': name,
    'at': savedAt.toIso8601String(),
    'kind': kind,
    'bytes': bytes,
    'v': version,
    if (label.isNotEmpty) 'label': label,
    if (stored != bytes) 'sz': stored,
    if (edited != null) 'ed': edited!.toIso8601String(),
  };
  static StoredProject fromJson(Map<String, dynamic> j) => StoredProject(
    uid: j['uid'] as String,
    name: j['name'] as String? ?? '',
    savedAt: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
    kind: j['kind'] as String? ?? 'saved',
    bytes: (j['bytes'] as num?)?.toInt() ?? 0,
    version: (j['v'] as num?)?.toInt() ?? 0,
    label: j['label'] as String? ?? '',
    stored: (j['sz'] as num?)?.toInt(),
    edited: DateTime.tryParse(j['ed'] as String? ?? ''),
  );

  StoredProject copyWith({String? name, DateTime? savedAt, String? kind, int? bytes, int? stored, DateTime? edited}) => StoredProject(
    uid: uid,
    name: name ?? this.name,
    savedAt: savedAt ?? this.savedAt,
    kind: kind ?? this.kind,
    bytes: bytes ?? this.bytes,
    version: version,
    label: label,
    stored: stored ?? this.stored,
    edited: edited ?? this.edited,
  );
}

/// How a write went.
enum StoreStatus {
  /// Kept.
  ok,

  /// Larger than one entry may be, even compressed.
  tooLarge,

  /// The storage is full, even after dropping what may go.
  full,

  /// The storage cannot be written (blocked, private mode).
  unavailable,
}

class StoreOutcome {
  const StoreOutcome(this.status, {this.versionKept = true, this.dropped = 0});
  final StoreStatus status;

  /// A save kept its version too (false when only the copy fitted).
  final bool versionKept;

  /// Entries dropped to make room.
  final int dropped;

  bool get ok => status == StoreStatus.ok;

  static const done = StoreOutcome(StoreStatus.ok);
}

/// Repository of stored projects (browser storage).
abstract class ProjectRepository {
  List<StoredProject> list();
  Future<String?> load(String uid, {int? version});
  Future<StoreOutcome> save(String uid, String name, String json, {String kind = 'saved', String label = '', String? stored, DateTime? edited});
  Future<void> remove(String uid);
  List<StoredProject> versions(String uid);
}

class LocalProjectStore implements ProjectRepository {
  LocalProjectStore({this.maxProjects = 8, this.maxVersions = 10, int? maxBytes, BodyStore? bodies, WindowLocks? locks})
    : bodies = bodies ?? platformBodyStore(),
      _lockOverride = locks,
      _maxBytesOverride = maxBytes;
  final int maxProjects;
  final int maxVersions;

  /// Where the texts go (the platform's by default, shared by every store
  /// of the page).
  final BodyStore bodies;

  /// The coordination between windows (the platform's by default).
  final WindowLocks? _lockOverride;

  /// A lower limit than the storage's for one project (tests).
  final int? _maxBytesOverride;

  /// Characters one stored project may take, after the compression of large
  /// projects: the limit of the storage, or a lower one given to the store.
  int get maxBytes => math.min(_maxBytesOverride ?? bodies.maxEntryChars, bodies.maxEntryChars);

  /// Whether the writes complete during the call (memory, localStorage).
  bool get synchronous => bodies.synchronous;

  /// Projects larger than this (characters of JSON) are stored gzipped and
  /// base64-encoded, which keeps projects of tens of megabytes of JSON
  /// within the browser quota (their text compresses about tenfold).
  static const compressAbove = 256 * 1024;
  static const _gzip = 'gz:';

  /// The stored form of [json].
  static String encode(String json) {
    if (json.length <= compressAbove) return json;
    final packed = _gzip + base64Encode(const GZipEncoder().encodeBytes(utf8.encode(json)));
    // embedded pictures are compressed already and may not shrink
    return packed.length < json.length ? packed : json;
  }

  /// [encode] done by the platform where it can (the browser compresses
  /// beside the app's code, while [encode] holds the interface for as long
  /// as a large project takes): the same stored form, read by [decode].
  static Future<String> encodeAsync(String json) async {
    if (json.length <= compressAbove) return json;
    final b64 = await gzipBase64(json);
    if (b64 == null) return encode(json);
    final packed = _gzip + b64;
    return packed.length < json.length ? packed : json;
  }

  /// The JSON of a stored value (compressed or not); null when damaged.
  static String? decode(String? stored) {
    if (stored == null || !stored.startsWith(_gzip)) return stored;
    try {
      return utf8.decode(const GZipDecoder().decodeBytes(base64Decode(stored.substring(_gzip.length))));
    } catch (_) {
      return null;
    }
  }

  static const _index = 'store.index';
  static const _rescueIndex = 'store.rescue';

  static String _currentKey(String uid) => 'store.$uid';
  static String _versionKey(String uid, int v) => 'store.$uid.v$v';
  static String _keyOf(StoredProject e) => e.kind == 'version' ? _versionKey(e.uid, e.version) : _currentKey(e.uid);

  List<StoredProject> _readIndex() {
    final raw = getPref(_index);
    if (raw == null) return [];
    try {
      return ((jsonDecode(raw) as List).cast<Map<String, dynamic>>()).map(StoredProject.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  /// Writes the index; false when localStorage refused it.
  bool _writeIndex(List<StoredProject> idx) {
    idx.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final text = jsonEncode(idx.map((e) => e.toJson()).toList());
    setPref(_index, text);
    return getPref(_index) == text;
  }

  @override
  List<StoredProject> list() => _readIndex().where((e) => e.kind != 'version').toList();

  @override
  List<StoredProject> versions(String uid) => _readIndex().where((e) => e.uid == uid && e.kind == 'version').toList()..sort((a, b) => b.version.compareTo(a.version));

  /// Whether anything of project [uid] is kept.
  bool has(String uid) => _readIndex().any((e) => e.uid == uid);

  /// The entry of the copy of [uid] (not its versions); null when none.
  StoredProject? entry(String uid) => _readIndex().where((e) => e.uid == uid && e.kind != 'version').firstOrNull;

  /// Characters the stored texts take, by the index.
  int get storedChars => _readIndex().fold(0, (s, e) => s + e.stored);

  // ---------------------------------------------------------------- serial work

  /// The store work of this page, every store of it in turn (they share
  /// the texts and the index).
  static Future<void> _queue = Future<void>.value();

  /// Runs [op] after the store work already started in this page, and
  /// under the lock of the store across windows; at once (during the call)
  /// when the texts are written synchronously.
  Future<T> _serial<T>(Future<T> Function() op) {
    if (synchronous) return op();
    final locks = _lockOverride ?? windowLocks;
    final next = _queue.then((_) => locks.exclusive(op));
    _queue = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  @override
  Future<String?> load(String uid, {int? version}) async {
    final key = version == null ? _currentKey(uid) : _versionKey(uid, version);
    final r = bodies.get(key);
    var v = r is Future<String?> ? await r : r;
    // a text an older version left in localStorage, not moved yet
    v ??= bodies.kind == 'indexeddb' ? getPref(key) : null;
    return decode(v);
  }

  /// Saves the project. `autosave` overwrites the previous copy of the same
  /// uid; `saved` also records a version (version history). [stored] is
  /// [json] already encoded (see [encode]), when the caller has it. The
  /// copy is written first; the index is updated only for what was kept.
  @override
  Future<StoreOutcome> save(String uid, String name, String json, {String kind = 'saved', String label = '', String? stored, DateTime? edited}) =>
      _serial(() => _save(uid, name, json, kind: kind, label: label, stored: stored, edited: edited));

  Future<StoreOutcome> _save(String uid, String name, String json, {required String kind, required String label, String? stored, DateTime? edited}) async {
    final value = stored ?? encode(json);
    if (value.length > maxBytes) return const StoreOutcome(StoreStatus.tooLarge);
    final idx = _readIndex();
    var dropped = 0;
    // the copy first: it is what the recovery brings back
    var put = bodies.put(_currentKey(uid), value);
    var ok = put is Future<bool> ? await put : put;
    if (!ok) {
      for (final victim in _roomFor(uid, idx)) {
        final d = _dropEntry(victim, idx);
        if (d is Future) await d;
        dropped++;
        put = bodies.put(_currentKey(uid), value);
        ok = put is Future<bool> ? await put : put;
        if (ok) break;
      }
    }
    if (!ok) {
      // the entries dropped in vain are gone all the same: the index must
      // not list texts that are no longer there
      if (dropped > 0) _writeIndex(idx);
      // nothing kept and nothing written: the storage refuses every write (blocked, private mode)
      return StoreOutcome(idx.isEmpty ? StoreStatus.unavailable : StoreStatus.full, dropped: dropped);
    }
    final now = DateTime.now();
    var versionKept = true;
    var version = 0;
    if (kind == 'saved') {
      final vs = idx.where((e) => e.uid == uid && e.kind == 'version').toList()..sort((a, b) => b.version.compareTo(a.version));
      version = (vs.isEmpty ? 0 : vs.first.version) + 1;
      var vput = bodies.put(_versionKey(uid, version), value);
      var vok = vput is Future<bool> ? await vput : vput;
      // room for the version: the oldest versions of this project
      for (final old in vs.reversed) {
        if (vok) break;
        final d = _dropEntry(old, idx);
        if (d is Future) await d;
        dropped++;
        vput = bodies.put(_versionKey(uid, version), value);
        vok = vput is Future<bool> ? await vput : vput;
      }
      versionKept = vok;
      if (vok) {
        idx.add(StoredProject(uid: uid, name: name, savedAt: now, kind: 'version', bytes: json.length, version: version, label: label, stored: value.length, edited: edited));
        // keep only the last versions
        final all = idx.where((e) => e.uid == uid && e.kind == 'version').toList()..sort((a, b) => b.version.compareTo(a.version));
        for (final old in all.skip(maxVersions)) {
          final d = _dropEntry(old, idx);
          if (d is Future) await d;
        }
      }
    }
    idx.removeWhere((e) => e.uid == uid && e.kind != 'version');
    idx.add(StoredProject(uid: uid, name: name, savedAt: now, kind: kind, bytes: json.length, version: version, stored: value.length, edited: edited));
    // cap the number of projects (projects saved to a file go first) and the characters kept
    final projects = idx.where((e) => e.kind != 'version' && e.uid != uid).toList()..sort((a, b) => _dropOrder(a, b));
    var count = projects.length + 1;
    for (final old in projects) {
      if (count <= maxProjects) break;
      final d = _dropProject(old.uid, idx);
      if (d is Future) await d;
      count--;
    }
    var total = idx.fold(0, (s, e) => s + e.stored);
    for (final victim in _versionsOldestFirst(idx, keepNewestOf: true)) {
      if (total <= bodies.maxTotalChars) break;
      total -= victim.stored;
      final d = _dropEntry(victim, idx);
      if (d is Future) await d;
    }
    if (!_writeIndex(idx)) return StoreOutcome(StoreStatus.full, dropped: dropped, versionKept: versionKept);
    return StoreOutcome(StoreStatus.ok, versionKept: versionKept, dropped: dropped);
  }

  /// Projects saved to a file go before copies with unsaved changes; the
  /// oldest first.
  static int _dropOrder(StoredProject a, StoredProject b) {
    final ka = a.kind == 'autosave' ? 1 : 0, kb = b.kind == 'autosave' ? 1 : 0;
    if (ka != kb) return ka - kb;
    return a.savedAt.compareTo(b.savedAt);
  }

  /// Versions oldest first; with [keepNewestOf] the newest version of each
  /// project is left out.
  static List<StoredProject> _versionsOldestFirst(List<StoredProject> idx, {bool keepNewestOf = false}) {
    final vs = idx.where((e) => e.kind == 'version').toList();
    final newest = <String, int>{};
    for (final v in vs) {
      newest[v.uid] = math.max(newest[v.uid] ?? 0, v.version);
    }
    return [
      for (final v in vs..sort((a, b) => a.savedAt.compareTo(b.savedAt)))
        if (!keepNewestOf || v.version != newest[v.uid]) v,
    ];
  }

  /// What may go to make room for the copy of [uid], in order: the oldest
  /// versions of [uid] (its newest stays), the versions of the other
  /// projects (oldest first), then the other projects saved to a file
  /// (oldest first, with their versions). Never a copy with changes not
  /// saved to a file.
  List<StoredProject> _roomFor(String uid, List<StoredProject> idx) {
    final own = idx.where((e) => e.uid == uid && e.kind == 'version').toList()..sort((a, b) => a.version.compareTo(b.version));
    if (own.isNotEmpty) own.removeLast();
    final others = _versionsOldestFirst(idx).where((e) => e.uid != uid).toList();
    final saved = idx.where((e) => e.uid != uid && e.kind == 'saved').toList()..sort((a, b) => a.savedAt.compareTo(b.savedAt));
    return [...own, ...others, ...saved];
  }

  /// Drops entry [e] and its text: a future only when the storage answers
  /// with one (so a synchronous store finishes during the call).
  FutureOr<void> _dropEntry(StoredProject e, List<StoredProject> idx) {
    if (!idx.remove(e)) return null;
    // a text an older version left in localStorage goes too
    if (bodies.kind == 'indexeddb') removePref(_keyOf(e));
    return bodies.delete(_keyOf(e));
  }

  FutureOr<void> _dropProject(String uid, List<StoredProject> idx) {
    final pending = <Future<void>>[];
    for (final e in idx.where((e) => e.uid == uid).toList()) {
      final d = _dropEntry(e, idx);
      if (d is Future<void>) pending.add(d);
    }
    if (pending.isEmpty) return null;
    return Future.wait(pending).then((_) {});
  }

  @override
  Future<void> remove(String uid) => _serial(() async {
    final idx = _readIndex();
    final d = _dropProject(uid, idx);
    if (d is Future) await d;
    _writeIndex(idx);
  });

  /// Autosaves that were not turned into a normal save (crash recovery).
  List<StoredProject> recoverable() => list().where((e) => e.kind == 'autosave').toList();

  /// Marks an autosave as acknowledged (keeps it as a recent project).
  void acknowledge(String uid) {
    final idx = _readIndex();
    final i = idx.indexWhere((e) => e.uid == uid && e.kind == 'autosave');
    if (i < 0) return;
    idx[i] = idx[i].copyWith(kind: 'saved');
    _writeIndex(idx);
  }

  /// "Discard" in the recovery: drops the copy with the changes not saved to
  /// a file and goes back to the last saved version, keeping the version
  /// history and the recent entry; a project never saved (no version) is
  /// forgotten.
  Future<void> discardAutosave(String uid) => _serial(() async {
    final idx = _readIndex();
    final cur = idx.where((e) => e.uid == uid && e.kind == 'autosave').firstOrNull;
    if (cur == null) return;
    final vs = idx.where((e) => e.uid == uid && e.kind == 'version').toList()..sort((a, b) => b.version.compareTo(a.version));
    if (vs.isEmpty) {
      final d = _dropProject(uid, idx);
      if (d is Future) await d;
      _writeIndex(idx);
      return;
    }
    final latest = vs.first;
    final g = bodies.get(_versionKey(uid, latest.version));
    final body = g is Future<String?> ? await g : g;
    if (body != null) {
      final p = bodies.put(_currentKey(uid), body);
      if (!(p is Future<bool> ? await p : p)) return;
    }
    final i = idx.indexOf(cur);
    idx[i] = cur.copyWith(kind: 'saved', savedAt: latest.savedAt, bytes: latest.bytes, stored: latest.stored, edited: latest.edited);
    _writeIndex(idx);
  });

  /// Removes every stored project and version (tests, "clear browser data").
  void clearAll() {
    final idx = _readIndex();
    for (final e in idx) {
      removePref(_keyOf(e));
      if (bodies.kind != 'localstorage') {
        final d = bodies.delete(_keyOf(e));
        if (d is Future) unawaited(d);
      }
    }
    final c = bodies.clear();
    if (c is Future) unawaited(c);
    for (final r in _rescues()) {
      removePref('$_rescueIndex.${r.uid}');
    }
    removePref(_rescueIndex);
    removePref(_index);
  }

  /// Renames the entry (after the project name changes).
  void rename(String uid, String name) {
    final idx = _readIndex();
    for (var i = 0; i < idx.length; i++) {
      if (idx[i].uid == uid) idx[i] = idx[i].copyWith(name: name);
    }
    _writeIndex(idx);
  }

  // ---------------------------------------------------------------- rescue copies

  /// The copies written when the page was being closed.
  List<StoredProject> _rescues() {
    final raw = getPref(_rescueIndex);
    if (raw == null) return [];
    try {
      return ((jsonDecode(raw) as List).cast<Map<String, dynamic>>()).map(StoredProject.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  /// Keeps [stored] (the stored form of the project JSON of [bytes]
  /// characters) at once, in localStorage: called while the page is being
  /// closed, when the database may not finish a write. [prepare] turns it
  /// into the copy of the project at the next start. False when it does
  /// not fit.
  bool rescue(String uid, String name, String stored, {required int bytes, DateTime? edited}) {
    final key = '$_rescueIndex.$uid';
    setPref(key, stored);
    if (getPref(key) != stored) {
      removePref(key);
      return false;
    }
    final list = _rescues()..removeWhere((e) => e.uid == uid);
    list.add(StoredProject(uid: uid, name: name, savedAt: DateTime.now(), kind: 'autosave', bytes: bytes, stored: stored.length, edited: edited));
    final text = jsonEncode([for (final e in list) e.toJson()]);
    setPref(_rescueIndex, text);
    return getPref(_rescueIndex) == text;
  }

  static Future<void>? _prepared;

  /// Gets the storage ready at start-up (once per page): opens it, moves the
  /// texts an older version kept in localStorage into the database, and
  /// turns the copies written while the page was closing into the copies of
  /// their projects (offered by the recovery).
  Future<void> prepare() {
    // a synchronous store is ready during the call (and a future kept from
    // one test zone would never complete in the next)
    if (synchronous) return _serial(_prepare);
    return _prepared ??= _serial(_prepare);
  }

  /// Forgets that [prepare] ran (tests).
  static void debugResetPrepared() => _prepared = null;

  Future<void> _prepare() async {
    final o = bodies.open();
    if (o is Future) await o;
    final idx = _readIndex();
    var changed = false;
    if (bodies.kind == 'indexeddb') {
      for (final e in idx) {
        final key = _keyOf(e);
        final legacy = getPref(key);
        if (legacy == null) continue;
        final have = await bodies.get(key);
        final ok = have != null || await bodies.put(key, legacy);
        if (ok) removePref(key);
      }
    }
    for (final r in _rescues()) {
      final key = '$_rescueIndex.${r.uid}';
      final text = getPref(key);
      final cur = idx.where((e) => e.uid == r.uid && e.kind != 'version').firstOrNull;
      // the rescue holds the newer edits unless the copy of the database got them too
      if (text != null && (cur == null || cur.editedOrSaved.isBefore(r.editedOrSaved) || (r.edited == null && cur.savedAt.isBefore(r.savedAt)))) {
        final p = bodies.put(_currentKey(r.uid), text);
        if (!(p is Future<bool> ? await p : p)) continue; // tried again at the next start
        idx.removeWhere((e) => e.uid == r.uid && e.kind != 'version');
        idx.add(r.copyWith(kind: 'autosave'));
        changed = true;
      }
      removePref(key);
    }
    removePref(_rescueIndex);
    if (changed) _writeIndex(idx);
  }
}
