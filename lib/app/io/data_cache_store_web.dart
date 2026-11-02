/// Browser: the downloads kept in the IndexedDB database
/// `opencadirrigation-cache` of this site (one object store, `entries`:
/// per key an object with the data and the date). A browser that cannot
/// open the database (storage blocked, some private modes) keeps them in
/// memory for the page.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../core/io/data_cache.dart';

DataCacheStore platformDataCacheStore() => _IdbDataCacheStore();

class _IdbDataCacheStore implements DataCacheStore {
  static const _name = 'opencadirrigation-cache';
  static const _entries = 'entries';

  final _fallback = MemoryDataCacheStore();
  Future<web.IDBDatabase?>? _open;
  bool? _available;

  @override
  String get kind => _available == false ? _fallback.kind : 'indexeddb';

  @override
  String get location => '';

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
        if (!db.objectStoreNames.contains(_entries)) db.createObjectStore(_entries);
      }).toJS;
      req.onsuccess = ((web.Event _) {
        final db = req.result as web.IDBDatabase;
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

  /// Runs [body] in one transaction: true once committed.
  Future<bool> _run(String mode, void Function(web.IDBObjectStore s) body) async {
    final db = await _database();
    if (db == null) return false;
    final done = Completer<bool>();
    try {
      final tx = db.transaction(_entries.toJS, mode);
      tx.oncomplete = ((web.Event _) {
        if (!done.isCompleted) done.complete(true);
      }).toJS;
      tx.onabort = ((web.Event _) {
        if (!done.isCompleted) done.complete(false);
      }).toJS;
      body(tx.objectStore(_entries));
    } catch (_) {
      _open = null;
      if (!done.isCompleted) done.complete(false);
    }
    return done.future;
  }

  static JSObject _record(Uint8List value, DateTime date) {
    final o = JSObject();
    o.setProperty('data'.toJS, value.toJS);
    o.setProperty('date'.toJS, date.millisecondsSinceEpoch.toJS);
    return o;
  }

  @override
  Future<Uint8List?> get(String key) async {
    if (await _database() == null) return _fallback.get(key);
    web.IDBRequest? req;
    final ok = await _run('readonly', (s) => req = s.get(key.toJS));
    final v = req?.result;
    if (!ok || v == null || !v.isA<JSObject>()) return null;
    final data = (v as JSObject).getProperty('data'.toJS);
    if (data == null || !data.isA<JSUint8Array>()) return null;
    return (data as JSUint8Array).toDart;
  }

  @override
  Future<void> put(String key, Uint8List value, DateTime date) async {
    if (await _database() == null) return _fallback.put(key, value, date);
    await _run('readwrite', (s) => s.put(_record(value, date), key.toJS));
  }

  @override
  Future<void> remove(String key) async {
    if (await _database() == null) return _fallback.remove(key);
    await _run('readwrite', (s) => s.delete(key.toJS));
  }

  @override
  Future<List<DataCacheEntry>> entries() async {
    if (await _database() == null) return _fallback.entries();
    final out = <DataCacheEntry>[];
    await _run('readonly', (s) {
      final req = s.openCursor();
      req.onsuccess = ((web.Event _) {
        final cursor = req.result;
        if (cursor == null) return;
        final c = cursor as web.IDBCursorWithValue;
        final key = c.key;
        final v = c.value;
        if (key != null && key.isA<JSString>() && v != null && v.isA<JSObject>()) {
          final o = v as JSObject;
          final data = o.getProperty('data'.toJS);
          final date = o.getProperty('date'.toJS);
          final bytes = data != null && data.isA<JSUint8Array>() ? (data as JSUint8Array).toDart.length : 0;
          final ms = date != null && date.isA<JSNumber>() ? (date as JSNumber).toDartDouble.round() : 0;
          out.add(DataCacheEntry((key as JSString).toDart, bytes, DateTime.fromMillisecondsSinceEpoch(ms)));
        }
        c.continue_();
      }).toJS;
    });
    return out;
  }

  @override
  Future<void> clear() async {
    if (await _database() == null) return _fallback.clear();
    await _run('readwrite', (s) => s.clear());
  }
}
