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

  // ------------------------------------------------ claims (Web Locks)
  //
  // Two Web Locks are held per project uid, on purpose apart:
  // `opencadirrigation.project.<uid>` (window_locks_web.dart) by the window
  // that has the project open, and `opencadirrigation-ai-chat:<uid>` (here)
  // by the page whose assistant keeps that project's conversations. Their
  // lives differ: the project's goes with the tab's project (another file
  // opened in the tab, the tab closed); the conversation's goes when no
  // assistant of the page keeps that uid any more — later than the project
  // during a task (the conversation moves to the new project only when the
  // task ends), and without one while no assistant was ever opened. One
  // lock for both would need a count of holders and a release that waits
  // for both sides, more code than the second name. Both are requested
  // with ifAvailable (never waited for), so they cannot deadlock; a project
  // opened in a second window takes a uid of its own (a copy), so its
  // assistant claims another name too. resumePristine asks this lock before
  // a new empty project adopts the uid of a kept conversation: a live page
  // that keeps that conversation holds it.

  /// Claims held by this page: the lock is held while its completer is not
  /// completed. Claims on their way share one future.
  final Map<String, Completer<void>> _held = {};
  final Map<String, Future<bool>> _asking = {};

  static String _lock(String uid) => 'opencadirrigation-ai-chat:$uid';

  @override
  Future<bool> claim(String uid) {
    if (_held.containsKey(uid)) return Future.value(true);
    return _asking[uid] ??= _request(uid).whenComplete(() => _asking.remove(uid));
  }

  Future<bool> _request(String uid) {
    final granted = Completer<bool>();
    try {
      final locks = web.window.navigator.locks;
      final hold = Completer<void>();
      locks
          .request(
            _lock(uid),
            web.LockOptions(ifAvailable: true),
            ((web.Lock? lock) {
              if (lock == null) {
                if (!granted.isCompleted) granted.complete(false);
                return null;
              }
              _held[uid] = hold;
              if (!granted.isCompleted) granted.complete(true);
              // held until [release] (or the page closes)
              return hold.future.toJS;
            }).toJS,
          )
          .toDart
          .then(
            (_) {},
            onError: (Object _) {
              if (!granted.isCompleted) granted.complete(true);
            },
          );
    } catch (_) {
      // a browser without Web Locks: as before, this page keeps the conversation
      if (!granted.isCompleted) granted.complete(true);
    }
    return granted.future;
  }

  @override
  void release(String uid) {
    final h = _held.remove(uid);
    if (h != null && !h.isCompleted) h.complete();
  }

  @override
  Future<bool> claimed(String uid) async {
    if (_held.containsKey(uid)) return true;
    try {
      final snap = await web.window.navigator.locks.query().toDart;
      return snap.held.toDart.any((l) => l.name == _lock(uid));
    } catch (_) {
      return false;
    }
  }
}
