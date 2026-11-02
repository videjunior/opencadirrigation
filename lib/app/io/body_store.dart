/// Where the browser keeps the text of the projects it stores (the current
/// copy and the saved versions of each one), by key (conditional import).
///
/// In the browser it is the IndexedDB database `opencadirrigation-projects`
/// of this site, whose quota is hundreds of megabytes or more; until 1.6.0
/// the projects were in localStorage, about 5 MB for the whole site, which a
/// few saves of a medium project filled. When the database cannot be opened
/// (storage blocked, some private modes) the texts stay in localStorage, as
/// before. Elsewhere (desktop builds, tests) they are kept in memory.
///
/// The memory and localStorage stores answer at once (plain values, no
/// futures): the project store then completes its work during the call,
/// which keeps the tests deterministic; the database answers with futures.
library;

import 'dart:async';

import 'body_store_stub.dart' if (dart.library.js_interop) 'body_store_web.dart' as impl;
import 'prefs.dart';

/// Texts by key. No call throws: what cannot be read is missing and what
/// cannot be written says so (false).
abstract class BodyStore {
  /// `indexeddb`, `localstorage` or `memory`.
  String get kind;

  /// The calls answer with values instead of futures.
  bool get synchronous;

  /// Characters one text may take.
  int get maxEntryChars;

  /// Characters all the texts may take before the oldest versions go.
  int get maxTotalChars;

  /// Opens the storage (the database); the other calls wait for it.
  FutureOr<void> open();

  /// Keeps [value] under [key]: true once it is written for good.
  FutureOr<bool> put(String key, String value);

  FutureOr<String?> get(String key);

  FutureOr<void> delete(String key);

  /// Removes every text (tests, "clear browser data").
  FutureOr<void> clear();
}

/// The store of this platform: the database in the browser (localStorage
/// when it cannot be opened), memory elsewhere. One per page.
BodyStore platformBodyStore() => _platform ??= impl.platformBodyStore();
BodyStore? _platform;

/// Texts in memory: desktop builds and tests. [quotaChars] limits the
/// characters kept in all (a full browser store), and [failing] makes every
/// write fail (a store that cannot be written).
class MemoryBodyStore implements BodyStore {
  MemoryBodyStore({this.quotaChars, this.maxEntryChars = 64 * 1000 * 1000, this.maxTotalChars = 400 * 1000 * 1000});

  final Map<String, String> values = {};

  /// Characters kept in all at most (null: no limit).
  int? quotaChars;

  /// Every write fails while true.
  bool failing = false;

  @override
  final int maxEntryChars;

  @override
  final int maxTotalChars;

  @override
  String get kind => 'memory';

  @override
  bool get synchronous => true;

  int get usedChars => values.values.fold(0, (s, v) => s + v.length);

  @override
  void open() {}

  @override
  bool put(String key, String value) {
    if (failing) return false;
    final q = quotaChars;
    if (q != null && usedChars - (values[key]?.length ?? 0) + value.length > q) return false;
    values[key] = value;
    return true;
  }

  @override
  String? get(String key) => values[key];

  @override
  void delete(String key) => values.remove(key);

  @override
  void clear() => values.clear();
}

/// Texts in localStorage (through [setPref]), under the keys the projects
/// had before 1.6.0: the fallback when the database cannot be opened.
/// Every write is read back, so a full storage says so.
class PrefsBodyStore implements BodyStore {
  const PrefsBodyStore();

  @override
  String get kind => 'localstorage';

  @override
  bool get synchronous => true;

  /// localStorage holds about 5 MB for the whole site.
  @override
  int get maxEntryChars => 3500000;

  @override
  int get maxTotalChars => 4500000;

  @override
  void open() {}

  @override
  bool put(String key, String value) {
    setPref(key, value);
    return getPref(key) == value;
  }

  @override
  String? get(String key) => getPref(key);

  @override
  void delete(String key) => removePref(key);

  /// The keys are listed by the project index, which clears them.
  @override
  void clear() {}
}
