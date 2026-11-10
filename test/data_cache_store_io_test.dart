import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/data_cache_store_io.dart';
import 'package:opencadirrigation/core/io/data_cache.dart';

/// The downloads kept as files on a desktop (lib/app/io/data_cache_store_io.dart):
/// what goes in comes out, with its date and size in the list; a file that
/// answers another key, a file cut short and a file of something else answer
/// nothing; the folder is the user's cache folder, and under the test runner
/// nothing is kept.
void main() {
  late Directory dir;
  late FileDataCacheStore store;

  setUp(() {
    // the store makes its folder itself
    dir = Directory('${Directory.systemTemp.createTempSync('oci_cache').path}/downloads');
    store = FileDataCacheStore(dir);
  });
  tearDown(() {
    if (dir.parent.existsSync()) dir.parent.deleteSync(recursive: true);
  });

  Uint8List bytes(int n, [int seed = 0]) => Uint8List.fromList([for (var i = 0; i < n; i++) (i * 7 + seed) % 256]);

  test('a download kept comes back, with its key, size and date in the list', () async {
    expect(store.kind, 'files');
    expect(store.location, dir.path);
    expect(await store.entries(), isEmpty, reason: 'no folder yet');
    expect(await store.get('dem:-22.5,-47.5'), isNull);
    // a date past 2038: the milliseconds take more than 32 bits
    final date = DateTime(2041, 3, 9, 14, 5, 7, 123);
    await store.put('dem:-22.5,-47.5', bytes(1000), date);
    await store.put('climate:São Paulo/ação', bytes(10, 3), DateTime(2026, 11, 10));
    expect(await store.get('dem:-22.5,-47.5'), bytes(1000));
    expect(await store.get('climate:São Paulo/ação'), bytes(10, 3));
    final entries = await store.entries()
      ..sort((a, b) => a.key.compareTo(b.key));
    expect([for (final e in entries) (e.key, e.bytes, e.date)], [('climate:São Paulo/ação', 10, DateTime(2026, 11, 10)), ('dem:-22.5,-47.5', 1000, date)]);
    // the file is named by the kind of the key and a digest, and no temporary file is left
    final names = [for (final f in dir.listSync()) f.uri.pathSegments.last]..sort();
    expect(names, hasLength(2));
    expect(names[0], matches(RegExp(r'^climate_[0-9a-f]{16}\.bin$')));
    expect(names[1], matches(RegExp(r'^dem_[0-9a-f]{16}\.bin$')));
    // put again replaces
    await store.put('dem:-22.5,-47.5', bytes(5, 9), DateTime(2026));
    expect(await store.get('dem:-22.5,-47.5'), bytes(5, 9));
    expect(await store.entries(), hasLength(2));
  });

  test('removing one leaves the others, and clearing takes the folder away', () async {
    await store.put('a:1', bytes(3), DateTime(2026));
    await store.put('nokind', bytes(4), DateTime(2026));
    await store.remove('a:1');
    await store.remove('a:never there');
    expect(await store.get('a:1'), isNull);
    expect((await store.entries()).single.key, 'nokind');
    expect(dir.listSync().single.uri.pathSegments.last, startsWith('x_'), reason: 'a key without a kind');
    await store.clear();
    expect(dir.existsSync(), isFalse);
    await store.clear();
    expect(await store.entries(), isEmpty);
  });

  test('a file that answers another key, a file cut short and a file of something else answer nothing', () async {
    await store.put('a:1', bytes(40), DateTime(2026));
    final file = dir.listSync().whereType<File>().single;
    final whole = file.readAsBytesSync();
    // the same digest with another key inside: not this key's download
    final other = Uint8List.fromList(whole)..[4] = 'b'.codeUnitAt(0);
    file.writeAsBytesSync(other);
    expect(await store.get('a:1'), isNull);
    expect((await store.entries()).single.key, 'b:1', reason: 'the list shows what the file says');
    // cut inside the head, and shorter than any head
    file.writeAsBytesSync(whole.sublist(0, 13));
    expect(await store.get('a:1'), isNull);
    expect(await store.entries(), isEmpty);
    file.writeAsBytesSync(whole.sublist(0, 5));
    expect(await store.get('a:1'), isNull);
    expect(await store.entries(), isEmpty);
    // files that are not downloads are left alone
    file.deleteSync();
    File('${dir.path}/notes.txt').writeAsStringSync('not a download');
    Directory('${dir.path}/folder.bin').createSync();
    expect(await store.entries(), isEmpty);
  });

  test("the folder is the user's cache folder, and nothing is kept under the test runner", () {
    final d = cacheDirectory();
    final env = Platform.environment;
    if (Platform.isMacOS) {
      expect(d?.path, env['HOME'] == null ? isNull : '${env['HOME']}/Library/Caches/OpenCADIrrigation/downloads');
    } else if (Platform.isWindows) {
      expect(d?.path, anyOf(isNull, endsWith(r'\OpenCADIrrigation\downloads')));
    } else {
      final base = env['XDG_CACHE_HOME'] ?? (env['HOME'] == null ? null : '${env['HOME']}/.cache');
      expect(d?.path, base == null || base.isEmpty ? isNull : '$base/OpenCADIrrigation/downloads');
    }
    expect(platformDataCacheStore(), isA<NoDataCacheStore>());
  });
}
