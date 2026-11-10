/// Downloads kept on the device: the tiles and point batches of the online
/// elevation models and the climate series, by their address, with the
/// date they came. Reopening a project or making its terrain again reads
/// them from here instead of the network: it works with a poor connection
/// in the field and spares the quota of the climate service. The store is
/// the browser's IndexedDB on the web and files on the desktop (the app
/// layer gives it, lib/app/io/data_cache_store.dart); it holds at most
/// [DataCache.maxBytes], the oldest entries going first.
library;

import 'dart:convert';
import 'dart:typed_data';

/// One kept download.
class DataCacheEntry {
  const DataCacheEntry(this.key, this.bytes, this.date);

  /// `<kind>:<address>`.
  final String key;
  final int bytes;

  /// When it was downloaded.
  final DateTime date;

  /// `dem`, `climate` or `forecast` (1.7.0 FCT).
  String get kind => key.contains(':') ? key.substring(0, key.indexOf(':')) : '';
}

/// Where the downloads are kept.
abstract class DataCacheStore {
  /// `indexeddb`, `files`, `memory` or `none`.
  String get kind;

  /// The folder of a file store (empty for the others).
  String get location => '';

  Future<Uint8List?> get(String key);
  Future<void> put(String key, Uint8List value, DateTime date);
  Future<void> remove(String key);
  Future<List<DataCacheEntry>> entries();
  Future<void> clear();
}

/// Downloads in memory (tests, and browsers whose storage is blocked).
class MemoryDataCacheStore implements DataCacheStore {
  final Map<String, (Uint8List, DateTime)> values = {};

  @override
  String get kind => 'memory';
  @override
  String get location => '';
  @override
  Future<Uint8List?> get(String key) async => values[key]?.$1;
  @override
  Future<void> put(String key, Uint8List value, DateTime date) async {
    values[key] = (value, date);
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<List<DataCacheEntry>> entries() async => [for (final e in values.entries) DataCacheEntry(e.key, e.value.$1.length, e.value.$2)];
  @override
  Future<void> clear() async {
    values.clear();
  }
}

/// A store that keeps nothing.
class NoDataCacheStore implements DataCacheStore {
  const NoDataCacheStore();
  @override
  String get kind => 'none';
  @override
  String get location => '';
  @override
  Future<Uint8List?> get(String key) async => null;
  @override
  Future<void> put(String key, Uint8List value, DateTime date) async {}
  @override
  Future<void> remove(String key) async {}
  @override
  Future<List<DataCacheEntry>> entries() async => const [];
  @override
  Future<void> clear() async {}
}

/// What a kind of downloads takes.
class DataCacheStats {
  const DataCacheStats(this.count, this.bytes, this.oldest);
  final int count, bytes;
  final DateTime? oldest;
}

/// The downloads kept in [store], by kind (`dem`, `climate`).
class DataCache {
  DataCache(this.store, {this.maxBytes = 200 << 20, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  final DataCacheStore store;

  /// Most bytes kept in all; past it the oldest entries go.
  final int maxBytes;
  final DateTime Function() _clock;

  /// False: downloads are neither read from nor kept in the store.
  bool enabled = true;

  /// Bytes kept, once counted (null: not yet).
  int? _total;

  /// Reads and requests that the store answered (for the tests and the dialog).
  int hits = 0, misses = 0;

  /// [fetch] (GET address → text) through the store under [kind].
  Future<String> Function(String url) text(Future<String> Function(String url) fetch, String kind) => (url) async {
    final key = '$kind:$url';
    if (enabled) {
      final kept = await _get(key);
      if (kept != null) return utf8.decode(kept, allowMalformed: true);
    }
    final body = await fetch(url);
    if (enabled) await _put(key, Uint8List.fromList(utf8.encode(body)));
    return body;
  };

  /// [fetch] (GET address → bytes) through the store under [kind].
  Future<List<int>> Function(String url) bytes(Future<List<int>> Function(String url) fetch, String kind) => (url) async {
    final key = '$kind:$url';
    if (enabled) {
      final kept = await _get(key);
      if (kept != null) return kept;
    }
    final body = await fetch(url);
    if (enabled) await _put(key, Uint8List.fromList(body));
    return body;
  };

  /// The text kept under [kind] for [url]; null when none is or keeping is off (1.7.0 FCT: the forecast, whose text
  /// says until when it stays valid).
  Future<String?> keptText(String kind, String url) async {
    if (!enabled) return null;
    final kept = await _get('$kind:$url');
    return kept == null ? null : utf8.decode(kept, allowMalformed: true);
  }

  /// Keeps [text] under [kind] for [url], in place of what was kept (nothing when keeping is off).
  Future<void> keepText(String kind, String url, String text) async {
    if (enabled) await _put('$kind:$url', Uint8List.fromList(utf8.encode(text)));
  }

  Future<Uint8List?> _get(String key) async {
    try {
      final v = await store.get(key);
      if (v == null) {
        misses++;
      } else {
        hits++;
      }
      return v;
    } on Object {
      return null;
    }
  }

  Future<void> _put(String key, Uint8List value) async {
    if (value.length > maxBytes ~/ 4) return;
    try {
      _total ??= (await store.entries()).fold<int>(0, (s, e) => s + e.bytes);
      await store.put(key, value, _clock());
      _total = _total! + value.length;
      if (_total! > maxBytes) await _trim();
    } on Object {
      // a full or blocked store keeps nothing: the download still serves
    }
  }

  /// Drops the oldest entries until the store holds 80 % of [maxBytes].
  Future<void> _trim() async {
    final all = [...await store.entries()]..sort((a, b) => a.date.compareTo(b.date));
    var total = all.fold<int>(0, (s, e) => s + e.bytes);
    for (final e in all) {
      if (total <= maxBytes * 0.8) break;
      await store.remove(e.key);
      total -= e.bytes;
    }
    _total = total;
  }

  /// Count, size and oldest date of the entries of [kind] (all when null).
  Future<DataCacheStats> stats([String? kind]) async {
    final all = await store.entries();
    var n = 0, b = 0;
    DateTime? oldest;
    for (final e in all) {
      if (kind != null && e.kind != kind) continue;
      n++;
      b += e.bytes;
      if (oldest == null || e.date.isBefore(oldest)) oldest = e.date;
    }
    return DataCacheStats(n, b, oldest);
  }

  /// Removes the entries of [kind] (all when null).
  Future<int> clear([String? kind]) async {
    final all = await store.entries();
    var n = 0;
    if (kind == null) {
      n = all.length;
      await store.clear();
    } else {
      for (final e in all) {
        if (e.kind != kind) continue;
        await store.remove(e.key);
        n++;
      }
    }
    _total = null;
    return n;
  }
}
