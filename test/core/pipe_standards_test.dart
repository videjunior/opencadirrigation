import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/hydraulics/water_hammer.dart';
import 'package:opencadirrigation/core/io/catalog_io.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/catalog_check.dart';
import 'package:opencadirrigation/core/model/pipe_standards.dart';
import 'package:opencadirrigation/core/units.dart';

/// The generic pipe packs built from the standards (PRD-07): the tables of
/// ISO 1452-2, EN 12201-2, IS 4985 and IS 4984 (and the ASTM inch pipes),
/// the check of every wall against its pressure class and the reference
/// prices with their source.
void main() {
  final packs = standardCatalogPacks();

  void spotCheck(PipeStandard st, Map<String, Map<int, double>> published) {
    for (final c in published.entries) {
      for (final w in c.value.entries) {
        expect(st.seriesOf(c.key).walls[w.key], w.value, reason: '${st.id} ${c.key} dn ${w.key}');
      }
    }
  }

  group('tables', () {
    test('ISO 1452-2: the walls of the published tables; the same S is PN 8 up to dn 90 and PN 10 above', () {
      // walls printed by the Sardinian price list (UNI EN 1452-2) and the EN 1452-2 table
      spotCheck(iso1452Standard, {
        'pn6': {40: 1.5, 63: 2.0, 75: 2.3, 90: 2.8, 110: 2.7, 125: 3.1, 140: 3.5, 160: 4.0, 250: 6.2, 315: 7.7},
        'pn8': {32: 1.5, 110: 3.4, 180: 5.5, 315: 9.7},
        'pn10': {50: 2.4, 63: 3.0, 75: 3.6, 90: 4.3, 110: 4.2, 125: 4.8, 140: 5.4, 160: 6.2, 200: 7.7, 250: 9.6, 315: 12.1},
        'pn12_5': {25: 1.5, 32: 1.9, 110: 5.3, 315: 15.0},
        'pn16': {20: 1.5, 63: 4.7, 75: 5.6, 90: 6.7, 110: 6.6, 125: 7.4, 140: 8.3, 160: 9.5, 200: 11.9},
      });
      // design coefficient 2.5 up to dn 90 (10 MPa), 2.0 above (12.5 MPa)
      final pn8 = iso1452Standard.seriesOf('pn8'), pn10 = iso1452Standard.seriesOf('pn10');
      expect(pn10.designStressAt(90), 10);
      expect(pn10.designStressAt(110), 12.5);
      expect(pn8.walls[90], iso4065Wall(90, 12.5, minimum: 1.5));
      expect(pn10.walls[110], iso4065Wall(110, 12.5, minimum: 1.5));
      // every wall is the ISO 4065 value of the series S of its class and size
      const s = {'pn6': (16.0, 20.0), 'pn8': (12.5, 16.0), 'pn10': (10.0, 12.5), 'pn12_5': (8.0, 10.0), 'pn16': (6.3, 8.0)};
      for (final c in iso1452Standard.series) {
        final (small, large) = s[c.key]!;
        for (final w in c.walls.entries) {
          expect(w.value, iso4065Wall(w.key, w.key <= 90 ? small : large, minimum: 1.5), reason: '${c.key} ${w.key}');
        }
      }
      expect(iso1452Standard.series.map((c) => c.pnBar), [6, 8, 10, 12.5, 16]);
    });

    test('EN 12201-2: the published PE 100 walls; the ISO 4065 values but 32 mm SDR 11', () {
      // walls printed by a PE 100 data sheet (EN 12201) and by the Sardinian price list
      spotCheck(en12201Standard, {
        'sdr17': {32: 2.0, 40: 2.4, 50: 3.0, 63: 3.8, 90: 5.4, 110: 6.6, 125: 7.4, 160: 9.5, 250: 14.8, 315: 18.7},
        'sdr11': {25: 2.3, 32: 3.0, 40: 3.7, 63: 5.8, 90: 8.2, 110: 10.0, 160: 14.6, 225: 20.5, 250: 22.7, 315: 28.6},
      });
      const s = {'sdr26': 12.5, 'sdr21': 10.0, 'sdr17': 8.0, 'sdr13_6': 6.3, 'sdr11': 5.0};
      for (final c in en12201Standard.series) {
        for (final w in c.walls.entries) {
          final rule = iso4065Wall(w.key, s[c.key]!, minimum: 2.0);
          // the standard rounds the small sizes up to 2.0, 2.3 or 3.0 mm
          expect(w.value, c.key == 'sdr11' && w.key == 32 ? 3.0 : rule, reason: '${c.key} ${w.key}');
        }
        expect(c.designStressMpa, 8);
      }
      expect(iso4065Wall(32, 5.0, minimum: 2.0), 2.9);
      expect(en12201Standard.series.map((c) => c.pnBar), [6, 8, 10, 12.5, 16]);
    });

    test('IS 4985:2021 Table 1: the minimum walls, within 0.1 mm of P·d/(2σ + P) at 8.6 MPa', () {
      spotCheck(is4985Standard, {
        'class1': {90: 1.3, 140: 2.0, 315: 4.6},
        'class2': {63: 1.5, 110: 2.5, 180: 4.2},
        'class3': {40: 1.4, 110: 3.7, 315: 10.7},
        'class4': {25: 1.2, 160: 7.2, 315: 14.0},
        'class5': {20: 1.1, 110: 6.1, 315: 17.3},
        'class6': {20: 1.4, 160: 10.9, 315: 21.4},
      });
      // the first size of each class
      expect([for (final c in is4985Standard.series) c.walls.keys.first], [90, 63, 40, 25, 20, 20]);
      for (final c in is4985Standard.series) {
        final p = c.pnBar / 10;
        for (final w in c.walls.entries) {
          final rule = (p * w.key / (2 * 8.6 + p) * 10 - 1e-9).ceil() / 10;
          expect((w.value - rule).abs(), lessThanOrEqualTo(0.1 + 1e-9), reason: '${c.key} ${w.key}');
          expect(p * (w.key - w.value) / (2 * w.value), lessThanOrEqualTo(8.6 * 1.005), reason: '${c.key} ${w.key}');
        }
      }
    });

    test('IS 4984:2016 Table 4 (Amendment 2): dn/SDR rounded up, at least 2.0 mm; PN at 27 °C', () {
      spotCheck(is4984Standard, {
        // 5.3 mm since Amendment 1, 3.8 mm since Amendment 2
        'pe100_pn6': {40: 2.0, 110: 5.3, 315: 15.0},
        'pe100_pn8': {32: 2.0, 63: 3.8, 110: 6.5},
        'pe100_pn4': {75: 2.3, 160: 4.9, 315: 9.6},
        'pe100_pn16': {20: 2.3, 25: 2.8, 315: 35.0},
        'pe80_pn4': {50: 2.0, 250: 9.7},
      });
      const sdr = {
        'pe100_pn4': 33.0,
        'pe100_pn6': 21.0,
        'pe100_pn8': 17.0,
        'pe100_pn10': 13.6,
        'pe100_pn12_5': 11.0,
        'pe100_pn16': 9.0,
        'pe80_pn4': 26.0,
        'pe80_pn6': 17.0,
        'pe80_pn8': 13.6,
        'pe80_pn10': 11.0,
      };
      for (final c in is4984Standard.series) {
        final r = sdr[c.key]!;
        for (final w in c.walls.entries) {
          expect(w.value, math.max((w.key / r * 10 - 1e-9).ceil() / 10, 2.0), reason: '${c.key} ${w.key}');
        }
        // the class does not pass 2σ/(SDR − 1) × 0.85 (σ of its Table 1: PE 100 8 MPa, PE 80 6.3 MPa)
        final sigma = c.key.startsWith('pe100') ? 8.0 : 6.3;
        expect(c.pnBar / 10, lessThanOrEqualTo(2 * sigma / (r - 1) * 0.85 + 1e-9), reason: c.key);
        expect(c.designStressMpa, closeTo(sigma * 0.85, 1e-9), reason: c.key);
      }
    });
  });

  group('wall × class check', () {
    test('every pipe of the packs passes it and the plausibility rules', () {
      for (final pack in packs) {
        expect(standardCatalogIssues(pack.catalog), isEmpty, reason: pack.meta.id);
        expect(catalogPlausibility(pack.catalog), isEmpty, reason: pack.meta.id);
      }
      var n = 0;
      for (final pack in packs.skip(1)) {
        for (final p in pack.catalog.pipes) {
          final ref = standardPipeOf(p.id)!;
          expect(ref.standard.id, pack.meta.id, reason: p.id);
          expect(p.nominalMm, ref.dn.toDouble(), reason: p.id);
          expect(p.wallThicknessMm, ref.series.walls[ref.dn], reason: p.id);
          n++;
        }
      }
      expect(n, 82 + 80 + 92 + 161);
      // ISO 1452 PN 10, 110 mm: bore 110 − 2 × 4.2, 10 bar in metres of water
      final pipe = packs.firstWhere((k) => k.meta.id == 'iso1452').catalog.pipe('iso1452_pn10_110')!;
      expect(pipe.innerDiameterMm, 101.6);
      expect(pipe.pressureRatingM, 101.97);
      expect(pipeRatingHoopStressMpa(pipe), closeTo(1.0 * (110 / 4.2 - 1) / 2, 0.01));
    });

    test('a wall thinner than the table, a class too high for the wall, a wrong size are caught', () {
      PipeSpec pvc(double wall, double pnBar, {int dn = 110, double? bore}) => PipeSpec(
        id: 'x',
        name: 'x',
        nominalMm: dn.toDouble(),
        innerDiameterMm: bore ?? dn.toDouble() - 2 * wall,
        wallThicknessMm: wall,
        pressureRatingM: pnBar / barPerMeterHead,
      );
      final pn8 = iso1452Standard.seriesOf('pn8'), pn10 = iso1452Standard.seriesOf('pn10');
      expect(pipeStandardIssues(pvc(4.2, 10), pn10, 110), isEmpty);
      expect(pipeStandardIssues(pvc(3.9, 10), pn10, 110), contains(startsWith('wall_below_table:x')));
      // a PN 16 rating on the PN 10 wall
      expect(pipeStandardIssues(pvc(4.2, 16), pn10, 110).single, startsWith('class_above_wall:x'));
      // S 12.5 is PN 10 at 110 mm but PN 8 at 90 mm (design coefficient 2.5)
      expect(pipeStandardIssues(pvc(3.5, 8, dn: 90), pn8, 90), isEmpty);
      expect(pipeStandardIssues(pvc(3.5, 10, dn: 90), pn8, 90).single, startsWith('class_above_wall:x'));
      expect(pipeStandardIssues(pvc(4.2, 10), pn10, 100).single, 'size_not_in_table:x:100');
      expect(pipeStandardIssues(pvc(4.2, 10, bore: 100), pn10, 110), contains(startsWith('outside_diameter:x')));
      expect(pipeStandardIssues(pvc(4.2, 0), pn10, 110).single, 'no_rating:x');
      // PE 100 SDR 17 is PN 10, not PN 16
      final pe = PipeSpec(id: 'pe', name: 'pe', nominalMm: 110, innerDiameterMm: 96.8, wallThicknessMm: 6.6, material: PipeMaterial.pehd, pressureRatingM: 16 / barPerMeterHead);
      expect(pipeStandardIssues(pe, en12201Standard.seriesOf('sdr17'), 110).single, startsWith('class_above_wall:pe'));
      // a catalogue: only the pipes of the standards are looked at
      final c = Catalog(pipes: [pvc(4.2, 10), PipeSpec(id: 'iso1452_pn10_110', name: 'thin', nominalMm: 110, innerDiameterMm: 102.2, wallThicknessMm: 3.9, pressureRatingM: 101.97)]);
      final issues = standardCatalogIssues(c);
      expect(issues.length, 2);
      expect(issues[0], startsWith('wall_below_table:iso1452_pn10_110'));
      expect(issues[1], startsWith('class_above_wall:iso1452_pn10_110'));
      expect(standardPipeOf('iso1452_pn12_5_110')?.series.key, 'pn12_5');
      expect(standardPipeOf('is4984_pe100_pn12_5_20')?.dn, 20);
      expect(standardPipeOf('rb_5004'), isNull);
    });
  });

  group('prices', () {
    test('priced packs state their currency, the source of the prices and their date', () {
      const currencies = {'iso1452': 'EUR', 'en12201': 'EUR', 'is4985': 'INR', 'is4984': 'INR'};
      for (final pack in packs.skip(1)) {
        final m = pack.meta;
        expect(m.currency, currencies[m.id], reason: m.id);
        expect(m.pricesSource, contains('least-squares fit'), reason: m.id);
        expect(m.pricesDate, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')), reason: m.id);
        expect(m.sources.length, greaterThanOrEqualTo(2), reason: m.id);
        expect(m.brand, startsWith('Generic ('));
        expect(m.license, 'CC0-1.0');
        expect(pack.catalog.pipes.every((p) => p.costPerM > 0), isTrue, reason: m.id);
      }
      expect(packs.first.meta.id, 'astm');
      expect(packs.first.meta.currency, isEmpty);
      expect(packs.first.meta.pricesSource, isEmpty);
      expect(packs.first.catalog.pipes.every((p) => p.costPerM == 0), isTrue);
    });

    test('published rows are used as printed, the others follow the fitted line', () {
      for (final st in pipeStandards) {
        final book = st.prices!;
        final (a, b) = pipePriceFit(st);
        expect(a, greaterThanOrEqualTo(0));
        expect(b, greaterThan(0));
        final pack = packs.firstWhere((p) => p.meta.id == st.id);
        for (final s in st.series) {
          for (final w in s.walls.entries) {
            final pipe = pack.catalog.pipe('${st.id}_${s.key}_${w.key}')!;
            final line = a + b * pipeMassKgPerM(w.key.toDouble(), w.value, st.densityKgM3.toDouble());
            final published = book.rows[s.key]?[w.key];
            final misprint = book.misprints[s.key]?.contains(w.key) ?? false;
            if (published != null && !misprint) {
              expect(pipe.costPerM, published, reason: pipe.id);
              // a published row stays within a quarter of the line
              expect((published / line - 1).abs(), lessThan(0.25), reason: pipe.id);
            } else {
              expect(pipe.costPerM, closeTo(line, book.decimals == 0 ? 0.5 : 0.005), reason: pipe.id);
            }
          }
        }
      }
      // the misprint of the EN 12201 price list is far from the line
      final (ea, eb) = pipePriceFit(en12201Standard);
      expect(18.69 / (ea + eb * pipeMassKgPerM(90, 5.4, 960)) - 1, greaterThan(0.25));
      expect(packs.firstWhere((p) => p.meta.id == 'en12201').catalog.pipe('en12201_sdr17_90')!.costPerM, lessThan(18.69));
      // the Indian schedule leaves no fixed part: the price follows the mass
      expect(pipePriceFit(is4985Standard).$1, 0);
      expect(pipePricesSource(en12201Standard), contains('F.004.004'));
    });

    test('a larger pipe of a class costs more; a thicker class about as much or more', () {
      for (final st in pipeStandards) {
        final pack = packs.firstWhere((p) => p.meta.id == st.id);
        double cost(PipeSeries s, int dn) => pack.catalog.pipe('${st.id}_${s.key}_$dn')!.costPerM;
        for (final s in st.series) {
          final sizes = s.walls.keys.toList();
          for (var i = 1; i < sizes.length; i++) {
            expect(cost(s, sizes[i]), greaterThan(cost(s, sizes[i - 1])), reason: '${st.id} ${s.key} ${sizes[i]}');
          }
        }
        final grades = st.id == 'is4984' ? [st.series.where((s) => s.key.startsWith('pe100_')).toList(), st.series.where((s) => s.key.startsWith('pe80_')).toList()] : [st.series];
        for (final g in grades) {
          for (var i = 1; i < g.length; i++) {
            for (final dn in g[i].walls.keys.where(g[i - 1].walls.containsKey)) {
              // published and fitted rows may cross by a few percent
              expect(cost(g[i], dn), greaterThanOrEqualTo(0.95 * cost(g[i - 1], dn)), reason: '${st.id} ${g[i].key} $dn');
            }
          }
        }
      }
    });
  });

  group('files', () {
    test('the files in catalogs/ are what the generator builds (dart run tool/gen_catalogs.dart)', () {
      expect(packs.map((p) => p.meta.id), ['astm', 'iso1452', 'en12201', 'is4985', 'is4984']);
      for (final pack in packs) {
        final file = File('catalogs/${pack.meta.id}$catalogPackExtension');
        expect(file.existsSync(), isTrue, reason: file.path);
        expect('${CatalogIo.encodePack(pack.meta, pack.catalog)}\n', file.readAsStringSync(), reason: '${pack.meta.id}: run dart run tool/gen_catalogs.dart');
      }
    });

    test('ids are unique, lower case and prefixed by their pack', () {
      final ids = <String>{};
      final defaults = Catalog.defaultCatalog();
      for (final pack in packs) {
        expect(pack.meta.id, matches(RegExp(r'^[a-z0-9_-]+$')));
        for (final p in pack.catalog.pipes) {
          expect(ids.add(p.id), isTrue, reason: 'duplicate ${p.id}');
          expect(p.id, startsWith('${pack.meta.id}_'));
          expect(p.id, matches(RegExp(r'^[a-z0-9_]+$')));
          expect(defaults.pipe(p.id), isNull, reason: p.id);
        }
      }
      expect(ids.length, 38 + 82 + 80 + 92 + 161);
    });

    test('the price metadata survive a round trip; the index leaves the long note out', () {
      final pack = packs.firstWhere((p) => p.meta.id == 'iso1452');
      final back = CatalogIo.parsePack(CatalogIo.encodePack(pack.meta, pack.catalog));
      expect(back.meta.toJson(), pack.meta.toJson());
      expect(back.meta.pricesDate, '2024-12-12');
      final entry = CatalogIndexEntry(meta: pack.meta, file: 'iso1452.oci.cat', items: pack.itemCount).toJson();
      expect(entry.containsKey('pricesSource'), isFalse);
      expect(entry.containsKey('sources'), isFalse);
      expect(entry['pricesDate'], '2024-12-12');
      // read leniently
      final odd = CatalogPackMeta.fromJson({'id': 'x', 'brand': 'X', 'pricesSource': 12, 'pricesDate': ' 2024-01-31 '});
      expect(odd.pricesSource, isEmpty);
      expect(odd.pricesDate, '2024-01-31');
      expect(odd.toJson().containsKey('pricesSource'), isFalse);
    });
  });
}
