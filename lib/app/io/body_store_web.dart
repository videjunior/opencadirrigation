/// Browser: the texts of the stored projects in the IndexedDB database
/// `opencadirrigation-projects` of this site (one object store, `bodies`,
/// text by key). A write is reported once its transaction commits; a full
/// storage aborts it, which reads as a failed write. A browser that cannot
/// open the database keeps the texts in localStorage instead.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'body_store.dart';

BodyStore platformBodyStore() => _IdbBodyStore();

class _IdbBodyStore implements BodyStore {
  static const _name = 'opencadirrigation-projects';
  static const _bodies = 'bodies';

  final _fallback = const PrefsBodyStore();
  Future<web.IDBDatabase?>? _open;

  /// Known once [open] completed: false when the texts stay in localStorage.
  bool? _available;

  @override
  String get kind => _available == false ? _fallback.kind : 'indexeddb';

  @override
  bool get synchronous => false;

  @override
  int get maxEntryChars => _available == false ? _fallback.maxEntryChars : 64 * 1000 * 1000;

  @override
  int get maxTotalChars => _available == false ? _fallback.maxTotalChars : 400 * 1000 * 1000;

  Future<web.IDBDatabase?> _database() => _open ??= _connect();

  Future<web.IDBDatabase?> _connect() {
    final done = Completer<web.IDBDatabase?>();
    void fail() {
      _available = false;
      if (!done.isCompleted) done.complete(null);
    }

    try {
      final req = web.window.indexedDB.open(_name, 1);
      req.onupgradeneeded = ((web.Event _) {
        final db = req.result as web.IDBDatabase;
        if (!db.objectStoreNames.contains(_bodies)) db.createObjectStore(_bodies);
      }).toJS;
      req.onsuccess = ((web.Event _) {
        final db = req.result as web.IDBDatabase;
        // a later version of the app in another window upgrades the database: this connection gives way
        db.onversionchange = ((web.Event _) {
          db.close();
          _open = null;
        }).toJS;
        _available = true;
        if (!done.isCompleted) done.complete(db);
      }).toJS;
      req.onerror = ((web.Event e) {
        e.preventDefault();
        fail();
      }).toJS;
      req.onblocked = ((web.Event _) => fail()).toJS;
    } catch (_) {
      fail();
    }
    return done.future;
  }

  @override
  Future<void> open() => _database();

  /// Runs [body] in one transaction: true once it is committed, false when
  /// it could not start or was aborted (a full storage aborts it).
  Future<bool> _run(String mode, void Function(web.IDBObjectStore s) body) async {
    final db = await _database();
    if (db == null) return false;
    final done = Completer<bool>();
    try {
      final tx = db.transaction(_bodies.toJS, mode);
      tx.oncomplete = ((web.Event _) {
        if (!done.isCompleted) done.complete(true);
      }).toJS;
      // a failed request (left to abort the transaction) and a full storage
      // (QuotaExceededError) both end here
      tx.onabort = ((web.Event _) {
        if (!done.isCompleted) done.complete(false);
      }).toJS;
      body(tx.objectStore(_bodies));
    } catch (_) {
      // the connection was closing, or a value the browser refused
      _open = null;
      if (!done.isCompleted) done.complete(false);
    }
    return done.future;
  }

  @override
  Future<bool> put(String key, String value) async {
    if (await _database() == null) return _fallback.put(key, value);
    return _run('readwrite', (s) => s.put(value.toJS, key.toJS));
  }

  @override
  Future<String?> get(String key) async {
    if (await _database() == null) return _fallback.get(key);
    web.IDBRequest? req;
    final ok = await _run('readonly', (s) => req = s.get(key.toJS));
    final v = req?.result;
    if (!ok || v == null || !v.isA<JSString>()) return null;
    return (v as JSString).toDart;
  }

  @override
  Future<void> delete(String key) async {
    if (await _database() == null) return _fallback.delete(key);
    await _run('readwrite', (s) => s.delete(key.toJS));
  }

  @override
  Future<void> clear() async {
    if (await _database() == null) return;
    await _run('readwrite', (s) => s.clear());
  }
}
