/// Where the AI assistant keeps its conversations between visits, by
/// project uid, so that a reload, or the project opened again later, brings
/// its conversation back (conditional import). In the browser it is an
/// IndexedDB database of this site: the storage of this browser on this
/// device, never uploaded anywhere (localStorage is too small for them:
/// about 5 MB for the whole site, which the projects and their autosaves
/// already use). Elsewhere (desktop builds, tests) they are kept in memory
/// for as long as the app runs.
///
/// A conversation is one JSON string of at most [ConversationStore.maxChars]
/// characters, kept with the time it was saved; the
/// [ConversationStore.maxKept] most recently saved stay, and saving one more
/// drops the least recently saved.
library;

import 'ai_store_stub.dart' if (dart.library.js_interop) 'ai_store_web.dart' as impl;

/// A conversation as it was kept: its JSON and when it was saved.
class StoredConversation {
  const StoredConversation(this.json, this.saved);
  final String json;
  final DateTime saved;
}

/// The conversations kept, by project uid. No call throws: what cannot be
/// read is missing, and what cannot be kept says so.
abstract class ConversationStore {
  /// Conversations kept at most (a project may keep several since 1.6.0).
  static const maxKept = 24;

  /// Characters of JSON one conversation may take.
  static const maxChars = 40 * 1000 * 1000;

  /// Keeps [json] as the conversation of [uid], in place of the earlier
  /// one; false when it is not kept (too large, the storage full or not
  /// available).
  Future<bool> save(String uid, String json);

  /// The conversation of [uid]; null when none is kept (or the storage
  /// cannot be read).
  Future<StoredConversation?> load(String uid);

  Future<void> delete(String uid);

  /// Deletes every conversation kept.
  Future<void> clear();

  /// When each conversation kept was saved, by uid.
  Future<Map<String, DateTime>> list();

  /// Claims the conversation of [uid] for this page: false while another
  /// page of this browser holds it (the same project open in two browser
  /// tabs, each of which would otherwise save over the other's). A page
  /// claims a uid once (claiming it again says true); the claim lasts until
  /// [release], or until the page closes.
  Future<bool> claim(String uid);

  /// Gives up the claim on [uid] (this page no longer keeps it).
  void release(String uid);

  /// Whether a page of this browser holds [uid] now (this one included).
  Future<bool> claimed(String uid);
}

/// The conversations of this platform: IndexedDB in the browser, memory
/// elsewhere.
ConversationStore platformConversationStore() => impl.platformConversationStore();

/// Conversations in memory: desktop builds and tests. [pages] holds the
/// claims of every "page" sharing it (tests give two stores one set to play
/// two browser tabs).
class MemoryConversationStore implements ConversationStore {
  MemoryConversationStore({Set<String>? pages, Map<String, StoredConversation>? kept}) : _pages = pages ?? {}, _kept = kept ?? {};
  final Set<String> _pages;
  final Set<String> _mine = {};

  @override
  Future<bool> claim(String uid) async {
    if (_mine.contains(uid)) return true;
    if (_pages.contains(uid)) return false;
    _pages.add(uid);
    _mine.add(uid);
    return true;
  }

  @override
  void release(String uid) {
    if (_mine.remove(uid)) _pages.remove(uid);
  }

  @override
  Future<bool> claimed(String uid) async => _pages.contains(uid);

  /// Oldest saved first (a conversation saved again moves to the end).
  final Map<String, StoredConversation> _kept;

  @override
  Future<bool> save(String uid, String json) async {
    if (json.length > ConversationStore.maxChars) return false;
    _kept
      ..remove(uid)
      ..[uid] = StoredConversation(json, DateTime.now());
    while (_kept.length > ConversationStore.maxKept) {
      _kept.remove(_kept.keys.first);
    }
    return true;
  }

  @override
  Future<StoredConversation?> load(String uid) async => _kept[uid];

  /// What is kept for [uid] now (tests read it in the middle of a turn).
  StoredConversation? debugKept(String uid) => _kept[uid];

  @override
  Future<void> delete(String uid) async => _kept.remove(uid);

  @override
  Future<void> clear() async => _kept.clear();

  @override
  Future<Map<String, DateTime>> list() async => {for (final e in _kept.entries) e.key: e.value.saved};
}
