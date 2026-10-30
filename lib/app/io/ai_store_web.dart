/// Browser: the conversations in the IndexedDB database
/// `opencadirrigation-ai` of this site. One object store holds the JSON of
/// each conversation by project uid, the other when each was saved: every
/// save reads those times to drop the least recently saved beyond
/// [ConversationStore.maxKept], without loading the conversations. A
/// browser that cannot open the database (storage blocked, some private
/// modes) keeps nothing, and every save says so.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'ai_store.dart';

ConversationStore platformConversationStore() => _IdbConversations();

class _IdbConversations implements ConversationStore {
  static const _name = 'opencadirrigation-ai';
  static const _chats = 'chats', _saved = 'saved';

  Future<web.IDBDatabase?>? _open;

  Future<web.IDBDatabase?> _database() => _open ??= _connect();

  Future<web.IDBDatabase?> _connect() {
    final done = Completer<web.IDBDatabase?>();
    void fail() {
      // tried again on the next call
      _open = null;
      if (!done.isCompleted) done.complete(null);
    }

    try {
      final req = web.window.indexedDB.open(_name, 1);
      req.onupgradeneeded = ((web.Event _) {
        final db = req.result as web.IDBDatabase;
        for (final name in const [_chats, _saved]) {
          if (!db.objectStoreNames.contains(name)) db.createObjectStore(name);
        }
      }).toJS;
      req.onsuccess = ((web.Event _) {
        final db = req.result as web.IDBDatabase;
        // a later version of the app in another tab upgrades the database: this connection gives way
        db.onversionchange = ((web.Event _) {
          db.close();
          _open = null;
        }).toJS;
        if (!done.isCompleted) done.complete(db);
      }).toJS;
      req.onerror = ((web.Event e) {
        e.preventDefault();
        fail();
      }).toJS;
    } catch (_) {
      fail();
    }
    return done.future;
  }

  /// Runs [body] in one transaction over both stores: true once it is
  /// committed, false when it could not start or was aborted (a full
  /// storage aborts it).
  Future<bool> _run(String mode, void Function(web.IDBObjectStore chats, web.IDBObjectStore saved) body) async {
    final db = await _database();
    if (db == null) return false;
    final done = Completer<bool>();
    try {
      final tx = db.transaction([_chats.toJS, _saved.toJS].toJS, mode);
      tx.oncomplete = ((web.Event _) {
        if (!done.isCompleted) done.complete(true);
      }).toJS;
      tx.onabort = ((web.Event _) {
        if (!done.isCompleted) done.complete(false);
      }).toJS;
      body(tx.objectStore(_chats), tx.objectStore(_saved));
    } catch (_) {
      // the connection was closing, or a value the browser refused
      _open = null;
      if (!done.isCompleted) done.complete(false);
    }
    return done.future;
  }

  /// Saved times by uid, from [keys] and [times] (getAllKeys and getAll of
  /// the store of times, in the same key order).
  static Map<String, DateTime> _times(web.IDBRequest keys, web.IDBRequest times) {
    final k = keys.result.dartify(), t = times.result.dartify();
    if (k is! List || t is! List || k.length != t.length) return {};
    return {
      for (var i = 0; i < k.length; i++)
        if (k[i] is String && t[i] is num) k[i] as String: DateTime.fromMillisecondsSinceEpoch((t[i] as num).toInt()),
    };
  }

  @override
  Future<bool> save(String uid, String json) async {
    if (json.length > ConversationStore.maxChars) return false;
    return _run('readwrite', (chats, saved) {
      chats.put(json.toJS, uid.toJS);
      saved.put(DateTime.now().millisecondsSinceEpoch.toJS, uid.toJS);
      // the least recently saved beyond the limit go, never this one
      final keys = saved.getAllKeys(), times = saved.getAll();
      times.onsuccess = ((web.Event _) {
        final all = _times(keys, times).entries.where((e) => e.key != uid).toList()..sort((a, b) => a.value.compareTo(b.value));
        for (var i = 0; i < all.length + 1 - ConversationStore.maxKept; i++) {
          chats.delete(all[i].key.toJS);
          saved.delete(all[i].key.toJS);
        }
      }).toJS;
    });
  }

  @override
  Future<StoredConversation?> load(String uid) async {
    web.IDBRequest? json, time;
    final ok = await _run('readonly', (chats, saved) {
      json = chats.get(uid.toJS);
      time = saved.get(uid.toJS);
    });
    final v = json?.result, t = time?.result.dartify();
    if (!ok || v == null || !v.isA<JSString>()) return null;
    return StoredConversation((v as JSString).toDart, t is num ? DateTime.fromMillisecondsSinceEpoch(t.toInt()) : DateTime.now());
  }

  @override
  Future<void> delete(String uid) => _run('readwrite', (chats, saved) {
    chats.delete(uid.toJS);
    saved.delete(uid.toJS);
  });

  @override
  Future<void> clear() => _run('readwrite', (chats, saved) {
    chats.clear();
    saved.clear();
  });

  @override
  Future<Map<String, DateTime>> list() async {
    web.IDBRequest? keys, times;
    final ok = await _run('readonly', (_, saved) {
      keys = saved.getAllKeys();
      times = saved.getAll();
    });
    return ok && keys != null && times != null ? _times(keys!, times!) : {};
  }
}
