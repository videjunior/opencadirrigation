/// Desktop: the downloads kept as files in the cache folder of the user
/// (`~/Library/Caches/OpenCADIrrigation` on macOS, `%LOCALAPPDATA%` on
/// Windows, `$XDG_CACHE_HOME` or `~/.cache` on Linux). Each file holds the
/// key it answers, its date and the data; its name is a digest of the key.
/// Under the test runner nothing is kept (the tests make their own stores).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../core/io/data_cache.dart';

DataCacheStore platformDataCacheStore() {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return const NoDataCacheStore();
  final dir = cacheDirectory();
  return dir == null ? MemoryDataCacheStore() : FileDataCacheStore(dir);
}

/// The cache folder of the app, or null when the platform names none.
Directory? cacheDirectory() {
  final env = Platform.environment;
  String? base;
  if (Platform.isMacOS) {
    final home = env['HOME'];
    if (home != null) base = '$home/Library/Caches';
  } else if (Platform.isWindows) {
    base = env['LOCALAPPDATA'] ?? env['APPDATA'];
  } else {
    base = env['XDG_CACHE_HOME'] ?? (env['HOME'] == null ? null : '${env['HOME']}/.cache');
  }
  if (base == null || base.isEmpty) return null;
  return Directory('$base${Platform.pathSeparator}OpenCADIrrigation${Platform.pathSeparator}downloads');
}

/// Downloads as files of [dir]: 4 bytes the key's length, the key in UTF-8,
/// 8 bytes the date (milliseconds since 1970), then the data.
class FileDataCacheStore implements DataCacheStore {
  FileDataCacheStore(this.dir);
  final Directory dir;

  @override
  String get kind => 'files';

  @override
  String get location => dir.path;

  /// The file of [key]: its kind and a 64-bit digest (FNV-1a, two halves).
  File _file(String key) {
    var a = 0x811C9DC5, b = 0x050C5D1F;
    for (final u in utf8.encode(key)) {
      a = ((a ^ u) * 16777619) & 0xFFFFFFFF;
      b = ((b ^ (u + 7)) * 16777619) & 0xFFFFFFFF;
    }
    final kind = key.contains(':') ? key.substring(0, key.indexOf(':')).replaceAll(RegExp(r'[^a-z]'), '') : 'x';
    String h(int v) => v.toRadixString(16).padLeft(8, '0');
    return File('${dir.path}${Platform.pathSeparator}${kind}_${h(a)}${h(b)}.bin');
  }

  static (String, DateTime, Uint8List)? _decode(Uint8List bytes) {
    if (bytes.length < 12) return null;
    final bd = ByteData.sublistView(bytes);
    final n = bd.getUint32(0, Endian.little);
    if (4 + n + 8 > bytes.length) return null;
    final key = utf8.decode(bytes.sublist(4, 4 + n), allowMalformed: true);
    final ms = bd.getUint32(4 + n, Endian.little) + bd.getUint32(8 + n, Endian.little) * 4294967296;
    return (key, DateTime.fromMillisecondsSinceEpoch(ms), Uint8List.sublistView(bytes, 12 + n));
  }

  @override
  Future<Uint8List?> get(String key) async {
    final f = _file(key);
    if (!await f.exists()) return null;
    final d = _decode(await f.readAsBytes());
    // a digest shared by another key answers nothing
    return d == null || d.$1 != key ? null : d.$3;
  }

  @override
  Future<void> put(String key, Uint8List value, DateTime date) async {
    await dir.create(recursive: true);
    final k = utf8.encode(key);
    final head = ByteData(12 + k.length);
    head.setUint32(0, k.length, Endian.little);
    for (var i = 0; i < k.length; i++) {
      head.setUint8(4 + i, k[i]);
    }
    final ms = date.millisecondsSinceEpoch;
    head.setUint32(4 + k.length, ms % 4294967296, Endian.little);
    head.setUint32(8 + k.length, ms ~/ 4294967296, Endian.little);
    final tmp = File('${_file(key).path}.tmp');
    await tmp.writeAsBytes([...head.buffer.asUint8List(), ...value], flush: true);
    await tmp.rename(_file(key).path);
  }

  @override
  Future<void> remove(String key) async {
    final f = _file(key);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<List<DataCacheEntry>> entries() async {
    if (!await dir.exists()) return const [];
    final out = <DataCacheEntry>[];
    await for (final e in dir.list()) {
      if (e is! File || !e.path.endsWith('.bin')) continue;
      // the head only: the key and the date
      final f = await e.open();
      try {
        final total = await f.length();
        final n = ByteData.sublistView(await f.read(4)).getUint32(0, Endian.little);
        if (4 + n + 8 > total) continue;
        final head = await f.read(n + 8);
        final bd = ByteData.sublistView(head);
        final ms = bd.getUint32(n, Endian.little) + bd.getUint32(n + 4, Endian.little) * 4294967296;
        out.add(DataCacheEntry(utf8.decode(head.sublist(0, n), allowMalformed: true), total - 12 - n, DateTime.fromMillisecondsSinceEpoch(ms)));
      } on Object {
        continue;
      } finally {
        await f.close();
      }
    }
    return out;
  }

  @override
  Future<void> clear() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
