import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/catalog_packs.dart';
import 'package:opencadirrigation/core/io/catalog_io.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/catalog_packs.dart';
import 'package:opencadirrigation/core/model/currency.dart';

/// Manufacturer catalogue packs: the `.oci.cat` format, the repository
/// folder `catalogs/` and the loaders (bundled assets, file, URL).
void main() {
  final dir = Directory('catalogs');
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith(catalogPackExtension)).toList()..sort((a, b) => a.path.compareTo(b.path));

  group('catalogs/ repository', () {
    test('every pack parses, is normalised and is listed in index.json', () {
      expect(files.length, greaterThanOrEqualTo(14));
      final index = CatalogIo.parseIndex(File('catalogs/index.json').readAsStringSync());
      expect(index.map((e) => e.file).toSet(), files.map((f) => f.uri.pathSegments.last).toSet());
      final ids = <String>{};
      final defaults = Catalog.defaultCatalog();
      for (final f in files) {
        final name = f.uri.pathSegments.last;
        final text = f.readAsStringSync();
        final pack = CatalogIo.parsePack(text);
        expect('${pack.meta.id}$catalogPackExtension', name, reason: 'file name = id');
        expect(pack.itemCount, greaterThan(0), reason: name);
        expect(pack.meta.brand, isNotEmpty);
        expect(pack.meta.description, isNotEmpty, reason: name);
        // normalised: rewriting the pack gives the same text (tool/gen_catalogs.dart --check)
        expect('${CatalogIo.encodePack(pack.meta, pack.catalog)}\n', text, reason: '$name: run dart run tool/gen_catalogs.dart');
        final entry = index.firstWhere((e) => e.file == name);
        expect(entry.items, pack.itemCount, reason: name);
        expect(entry.meta.brand, pack.meta.brand);
        for (final id in [...pack.catalog.pipes.map((e) => e.id), ...pack.catalog.outlets.map((e) => e.id), ...pack.catalog.tapes.map((e) => e.id), ...pack.catalog.valves.map((e) => e.id), ...pack.catalog.pumps.map((e) => e.id), ...pack.catalog.fittings.map((e) => e.id)]) {
          expect(ids.add(id), isTrue, reason: 'duplicate id $id in $name');
          expect(defaults.outlet(id) ?? defaults.tape(id) ?? defaults.valve(id) ?? defaults.pipe(id) ?? defaults.pump(id) ?? defaults.fitting(id), isNull, reason: '$id clashes with the built-in catalogue');
        }
        // curves are plausible
        for (final o in pack.catalog.outlets) {
          for (final nz in o.nozzles) {
            expect(nz.curve.k, greaterThan(0), reason: '${o.id}/${nz.id}');
            expect(nz.curve.x, inInclusiveRange(0, 1.2), reason: '${o.id}/${nz.id}');
          }
        }
      }
      expect(ids.length, greaterThan(200));
      // index.json itself is normalised
      expect('${CatalogIo.encodeIndex(index)}\n', File('catalogs/index.json').readAsStringSync());
    });

    test('pack data are consistent: sources, ranges, curves, losses and pump curves', () {
      for (final f in files) {
        final pack = CatalogIo.parsePack(f.readAsStringSync());
        final name = f.uri.pathSegments.last;
        expect(pack.meta.sources, isNotEmpty, reason: '$name: list the documents the data came from');
        expect(pack.meta.updated, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')), reason: name);
        final priced = catalogHasPrices(pack.catalog);
        expect(priced ? pack.meta.currency.isNotEmpty : true, isTrue, reason: '$name: a pack with prices states their currency');
        for (final o in pack.catalog.outlets) {
          expect(o.nozzles, isNotEmpty, reason: o.id);
          for (final n in o.nozzles) {
            final why = '$name ${o.id}/${n.id}';
            expect(n.minHeadM, lessThanOrEqualTo(n.defaultHeadM), reason: why);
            expect(n.defaultHeadM, lessThanOrEqualTo(n.maxHeadM), reason: why);
            expect(n.minHeadM, greaterThan(0), reason: why);
            final q = n.curve.flow(n.defaultHeadM) * 3.6e6; // L/h
            expect(q, inInclusiveRange(0.3, 70000), reason: '$why: $q L/h');
            final spray = o.kind == OutletKind.sprinkler || o.kind == OutletKind.microSprinkler || o.kind == OutletKind.gun;
            if (spray) expect(n.curve.radius(n.defaultHeadM), inInclusiveRange(1.0, 60.0), reason: why);
          }
        }
        for (final t in pack.catalog.tapes) {
          final why = '$name ${t.id}';
          expect(t.innerDiameterMm, inInclusiveRange(9, 30), reason: why);
          expect(t.emitterSpacingM, inInclusiveRange(0.1, 1.6), reason: why);
          expect(t.minHeadM, lessThan(t.maxHeadM), reason: why);
          expect(t.defaultInletHeadM, inInclusiveRange(t.minHeadM, t.maxHeadM), reason: why);
          expect(t.emitter.flow(t.defaultInletHeadM) * 3.6e6, inInclusiveRange(0.2, 16), reason: why);
        }
        for (final v in pack.catalog.valves) {
          final why = '$name ${v.id}';
          expect(v.maxFlow, greaterThan(v.minFlow), reason: why);
          final loss = v.loss.loss(v.maxFlow);
          expect(loss, inInclusiveRange(0.3, 30), reason: '$why: ${loss.toStringAsFixed(2)} m at the maximum flow');
          if (v.kind == ValveKind.prv) expect(v.defaultSettingM, greaterThan(0), reason: why);
        }
        for (final p in pack.catalog.pumps) {
          final why = '$name ${p.id}';
          expect(p.points.length, greaterThanOrEqualTo(3), reason: why);
          for (var i = 1; i < p.points.length; i++) {
            expect(p.points[i].$1, greaterThan(p.points[i - 1].$1), reason: '$why: flows increase');
            expect(p.points[i].$2, lessThanOrEqualTo(p.points[i - 1].$2 + 1e-9), reason: '$why: head falls with flow');
          }
          expect(p.efficiency, inInclusiveRange(0.3, 0.85), reason: why);
          expect(p.powerKw, greaterThan(0), reason: why);
        }
        for (final p in pack.catalog.pipes) {
          final why = '$name ${p.id}';
          expect(p.innerDiameterMm, greaterThan(0), reason: why);
          expect(p.wallThicknessMm, greaterThan(0), reason: why);
          expect(p.pressureRatingM, greaterThan(0), reason: why);
        }
      }
    });

    test('packs merge into a catalogue without id clashes', () {
      final c = Catalog.defaultCatalog();
      final before = c.itemCount;
      var added = 0;
      final packs = [for (final f in files) CatalogPack.parse(f.readAsStringSync(), origin: f.path)];
      for (final pack in packs) {
        expect(pack.isMergedInto(c), isFalse, reason: pack.id);
        added += mergeCatalogPack(c, pack.catalog);
        expect(pack.isMergedInto(c), isTrue, reason: pack.id);
      }
      expect(c.itemCount, before + added);
      expect(mergeCatalogPack(c, packs.first.catalog), 0, reason: 'already merged');
      expect(c.outlets.any((o) => o.supplier == 'Netafim'), isTrue);
      expect(c.valves.any((v) => v.supplier == 'Hunter Industries'), isTrue);
      final back = Catalog.fromJson(c.toJson());
      expect(back.itemCount, c.itemCount);
    });
  });

  group('pack file format', () {
    test('encode / parse round trip keeps metadata and items', () {
      final cat = Catalog.defaultCatalog(lang: 'pt');
      const meta = CatalogPackMeta(id: 'acme_2026', brand: 'ACME', name: 'ACME 2026', description: 'sprays', source: 'https://acme.example/ds.pdf', license: 'CC0-1.0', updated: '2026-09-16', author: 'me');
      final text = CatalogIo.encodePack(meta, cat);
      final j = jsonDecode(text) as Map<String, dynamic>;
      expect(j['format'], catalogPackFormat);
      expect(j['version'], catalogPackVersion);
      expect(j['items'], cat.itemCount);
      expect(CatalogIo.isPackJson(j), isTrue);
      expect(CatalogIo.isIndexJson(j), isFalse);
      final back = CatalogIo.parsePack(text);
      expect(back.meta.toJson(), meta.toJson());
      expect(back.itemCount, cat.itemCount);
      expect(back.catalog.pumps.map((p) => p.id), cat.pumps.map((p) => p.id));
      // the generic catalogue importer accepts a pack too
      final r = CatalogIo.parse(text);
      expect(r.count, cat.itemCount);
    });

    test('bare catalogues, ids from file names, errors', () {
      final cat = Catalog.defaultCatalog();
      final bare = CatalogIo.parsePack(CatalogIo.exportJson(cat), fallbackId: 'my_list');
      expect(bare.meta.id, 'my_list');
      expect(bare.meta.brand, 'my_list');
      expect(bare.itemCount, cat.itemCount);
      expect(CatalogPackMeta.idFrom('Rain Bird 5000.oci.cat'), 'rain_bird_5000');
      expect(CatalogPackMeta.idFrom('  Ünïcode ~~ .json'), 'n_code');
      expect(CatalogPackMeta.idFrom('.oci.cat'), 'pack');
      final pack = CatalogPack.parse(CatalogIo.exportJson(cat), origin: 'https://x.example/dir/Acme Sprays.oci.cat');
      expect(pack.id, 'acme_sprays');
      expect(pack.origin, contains('Acme'));
      expect(() => CatalogIo.parsePack('[1, 2]'), throwsFormatException);
      expect(() => CatalogIo.parsePack('{"hello": 1}'), throwsFormatException);
      expect(() => CatalogIo.parsePack(CatalogIo.encodeIndex(const [])), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'catalog_index_not_pack')));
      expect(() => CatalogIo.parsePack('{"format": "opencadirrigation-catalog", "version": 99, "id": "x", "brand": "x", "catalog": {}}'), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'catalog_pack_version')));
      expect(() => CatalogIo.parseIndex('{"a": 1}'), throwsFormatException);
    });

    test('index round trip', () {
      final entries = [
        const CatalogIndexEntry(meta: CatalogPackMeta(id: 'a', brand: 'A', description: 'd'), file: 'a.oci.cat', items: 3),
        const CatalogIndexEntry(meta: CatalogPackMeta(id: 'b', brand: 'B'), file: 'sub/b.oci.cat', items: 1),
      ];
      final back = CatalogIo.parseIndex(CatalogIo.encodeIndex(entries));
      expect(back.length, 2);
      expect(back[0].meta.id, 'a');
      expect(back[0].items, 3);
      expect(back[1].file, 'sub/b.oci.cat');
      // an entry without id takes it from the file name
      final loose = CatalogIo.parseIndex('{"packs": [{"file": "Toro Golf.oci.cat", "brand": "Toro"}]}');
      expect(loose.single.meta.id, 'toro_golf');
    });
  });

  group('loaders', () {
    test('bundled packs come from the asset folder (read from disk here)', () async {
      final saved = catalogAssetLoader;
      catalogAssetLoader = (path) async => File(path).readAsStringSync();
      try {
        final packs = await loadBundledCatalogPacks(refresh: true);
        expect(packs.length, files.length);
        expect(packs.map((p) => p.id), contains('rainbird'));
        expect(packs.every((p) => p.origin.isEmpty), isTrue);
        // cached
        expect(identical(await loadBundledCatalogPacks(), await loadBundledCatalogPacks()), isTrue);
      } finally {
        catalogAssetLoader = saved;
        await loadBundledCatalogPacks(refresh: true).catchError((_) => <CatalogPack>[]);
      }
    });

    test('a URL may point to a pack or to an index whose files resolve relative to it', () async {
      final saved = catalogUrlLoader;
      final rain = File('catalogs/rainbird.oci.cat').readAsStringSync();
      final toro = File('catalogs/toro.oci.cat').readAsStringSync();
      final served = <String, String>{
        'https://cat.example/repo/index.json': CatalogIo.encodeIndex([
          const CatalogIndexEntry(meta: CatalogPackMeta(id: 'rainbird', brand: 'Rain Bird'), file: 'rainbird.oci.cat'),
          const CatalogIndexEntry(meta: CatalogPackMeta(id: 'toro', brand: 'Toro'), file: 'packs/toro.oci.cat'),
        ]),
        'https://cat.example/repo/rainbird.oci.cat': rain,
        'https://cat.example/repo/packs/toro.oci.cat': toro,
        'https://cat.example/single.oci.cat': toro,
      };
      final requested = <String>[];
      catalogUrlLoader = (url) async {
        requested.add(url);
        final body = served[url];
        if (body == null) throw Exception('HTTP 404');
        return body;
      };
      try {
        final fromIndex = await loadCatalogPacksFromUrl('https://cat.example/repo/index.json');
        expect(fromIndex.map((p) => p.id), ['rainbird', 'toro']);
        expect(fromIndex[1].origin, 'https://cat.example/repo/packs/toro.oci.cat');
        final single = await loadCatalogPacksFromUrl(' https://cat.example/single.oci.cat ');
        expect(single.single.id, 'toro');
        expect(await loadCatalogPacksFromUrl(''), isEmpty);
        expect(loadCatalogPacksFromUrl('https://cat.example/missing'), throwsException);
        expect(requested, hasLength(5));
      } finally {
        catalogUrlLoader = saved;
      }
    });
  });
}
