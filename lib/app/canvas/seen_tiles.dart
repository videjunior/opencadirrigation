/// The base map tiles this page has shown (1.6.0, PRD-09), kept encoded by address, the least recently shown dropped
/// first past [SeenTiles.maxTiles] or [SeenTiles.maxBytes]: "Keep the map of the area for the field" composes the
/// area from what the user has looked at, without asking a tile server for anything more. The policy of the
/// OpenStreetMap Foundation's tile server forbids downloading areas of its tiles for offline use, and the other free
/// providers allow keeping what was shown at most. The Google maps are never kept (their terms do not allow it).
library;

import 'dart:typed_data';

class SeenTiles {
  SeenTiles({this.maxTiles = 400, this.maxBytes = 40 << 20});

  /// Most tiles and bytes kept.
  final int maxTiles, maxBytes;

  final Map<String, Uint8List> _bytes = {};
  int _total = 0;

  /// The tile at [url], marked as just used; null when it was not shown (or was dropped).
  Uint8List? operator [](String url) {
    final b = _bytes.remove(url);
    if (b != null) _bytes[url] = b;
    return b;
  }

  /// Keeps the tile at [url], dropping the least recently used past the limits.
  void put(String url, Uint8List bytes) {
    if (bytes.length > maxBytes) return;
    final old = _bytes.remove(url);
    if (old != null) _total -= old.length;
    _bytes[url] = bytes;
    _total += bytes.length;
    while (_bytes.length > maxTiles || _total > maxBytes) {
      final first = _bytes.keys.first;
      _total -= _bytes.remove(first)!.length;
    }
  }

  int get length => _bytes.length;

  /// Bytes kept.
  int get bytes => _total;

  void clear() {
    _bytes.clear();
    _total = 0;
  }
}

/// The tiles shown by the base map of every tab of this page.
final seenTiles = SeenTiles();
