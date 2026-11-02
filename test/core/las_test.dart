import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/io/datum.dart';
import 'package:opencadirrigation/core/io/las.dart';
import 'package:opencadirrigation/core/io/point_grid.dart';

/// The fixtures (test/fixtures/formats/las*.las, written by an independent
/// LAS writer) hold 651 ground points (class 2) on the plane below, 100
/// vegetation points (class 5) 8 m above it and 5 withheld ground points at
/// z = 0, in SIRGAS 2000 / UTM 23S (GeoTIFF keys for LAS 1.2 and 1.3, OGC
/// WKT for 1.4), plus the same points in SAD 69 / UTM 23S and a compressed copy.
const e0 = 186000.0, n0 = 8253200.0;
double plane(double e, double n) => 800 + 0.05 * (e - e0) + 0.02 * (n - n0);
Uint8List fixture(String name) => File('test/fixtures/formats/$name').readAsBytesSync();

void main() {
  final files = {
    'las12_f0.las': (2, 0),
    'las12_f1.las': (2, 1),
    'las12_f2.las': (2, 2),
    'las12_f3.las': (2, 3),
    'las13_f4.las': (3, 4),
    'las13_f5.las': (3, 5),
    'las14_f6.las': (4, 6),
    'las14_f7.las': (4, 7),
    'las14_f8.las': (4, 8),
    'las14_f9.las': (4, 9),
    'las14_f10.las': (4, 10),
  };

  test('every version and point format: ground points on the plane, CRS from the keys or the WKT', () {
    for (final f in files.entries) {
      final r = LasReader.read(fixture(f.key));
      expect(r.header.versionMinor, f.value.$1, reason: f.key);
      expect(r.header.pointFormat, f.value.$2, reason: f.key);
      expect(r.header.recordLength, greaterThanOrEqualTo(LasHeader.recordSizes[f.value.$2]));
      expect(r.pointsRead, 756);
      expect(r.classCounts, {2: 651, 5: 100}, reason: 'withheld points are skipped (${f.key})');
      expect(r.crs.epsgCode, 31983, reason: f.key);
      expect(r.crs.datum, GeodeticDatum.sirgas2000);
      expect(r.header.wkt, f.value.$1 == 4);
      expect(r.samples.length, lessThanOrEqualTo(12000));
      expect(r.samples.length, greaterThan(500));
      final g = r.georef!;
      expect(g.zone, 23);
      expect(g.north, isFalse);
      for (final s in r.samples) {
        // the mean of ground points of a cell lies on the plane: vegetation and
        // withheld points did not get in
        final (e, n) = g.toUtm(s.p.x, s.p.y);
        expect(s.z, closeTo(plane(e, n), 2e-3), reason: f.key);
      }
    }
  });

  test('decimation keeps the cloud within the limit', () {
    final r = LasReader.read(fixture('las14_f6.las'), maxPoints: 50);
    expect(r.samples.length, lessThanOrEqualTo(50));
    expect(r.samples.length, greaterThan(25));
    expect(r.cellSize, greaterThan(6));
    final g = r.georef!;
    for (final s in r.samples) {
      final (e, n) = g.toUtm(s.p.x, s.p.y);
      expect(s.z, closeTo(plane(e, n), 2e-3));
    }
    // every class, lowest point per cell: still the ground; mean: vegetation mixes in
    final low = LasReader.read(fixture('las14_f6.las'), classes: null, maxPoints: 50, reduce: GridReduce.lowest);
    for (final s in low.samples) {
      final (e, n) = low.georef!.toUtm(s.p.x, s.p.y);
      expect(s.z, closeTo(plane(e, n), 2e-3));
    }
    final mean = LasReader.read(fixture('las14_f6.las'), classes: null, maxPoints: 50);
    expect(
      mean.samples.any((s) {
        final (e, n) = mean.georef!.toUtm(s.p.x, s.p.y);
        return s.z > plane(e, n) + 0.1;
      }),
      isTrue,
    );
  });

  test('an unclassified cloud falls back to the lowest points', () {
    final r = LasReader.read(fixture('las14_unclassified.las'), maxPoints: 200);
    expect(r.warnings, containsAll(['las_no_class_points:2', 'las_lowest_points']));
    expect(r.classCounts, {1: 751});
    for (final s in r.samples) {
      final (e, n) = r.georef!.toUtm(s.p.x, s.p.y);
      expect(s.z, closeTo(plane(e, n), 2e-3));
    }
  });

  test('a header without bounds: the points are decimated at the end, the fallback still works', () {
    Uint8List noBounds(String name) {
      final b = Uint8List.fromList(fixture(name));
      b.fillRange(179, 227, 0); // max/min X, Y, Z
      return b;
    }

    for (final name in ['las14_f6.las', 'las14_unclassified.las', 'las12_f3.las']) {
      final r = LasReader.read(noBounds(name), maxPoints: 100);
      expect(r.samples.length, lessThanOrEqualTo(100), reason: name);
      expect(r.samples, isNotEmpty);
      for (final s in r.samples) {
        final (e, n) = r.georef!.toUtm(s.p.x, s.p.y);
        expect(s.z, closeTo(plane(e, n), 2e-3), reason: name);
      }
      expect(r.warnings.contains('las_lowest_points'), name == 'las14_unclassified.las');
    }
  });

  test('read in chunks of any size gives the same samples', () {
    final bytes = fixture('las13_f5.las');
    final whole = LasReader.read(bytes);
    for (final size in [1, 7, 333, 4096]) {
      final s = LasStreamReader();
      for (var o = 0; o < bytes.length; o += size) {
        s.add(bytes.sublist(o, math.min(o + size, bytes.length)));
      }
      final r = s.close();
      expect(r.samples.length, whole.samples.length, reason: '$size');
      for (var i = 0; i < r.samples.length; i++) {
        expect(r.samples[i].p, whole.samples[i].p);
        expect(r.samples[i].z, whole.samples[i].z);
      }
    }
  });

  test('SAD 69 coordinates land on the SIRGAS 2000 points (the IBGE translation)', () {
    final sirgas = LasReader.read(fixture('las12_f1.las'), maxPoints: 1000000);
    final sad = LasReader.read(fixture('las12_sad69.las'), maxPoints: 1000000, georef: sirgas.georef);
    expect(sad.crs.datum, GeodeticDatum.sad69);
    expect(sad.crs.epsgCode, 29193);
    expect(sad.warnings, contains(startsWith('crs_datum_shift:sad69')));
    expect(sad.samples.length, sirgas.samples.length);
    var worst = 0.0;
    for (final s in sad.samples) {
      var best = double.infinity;
      for (final t in sirgas.samples) {
        best = math.min(best, s.p.distanceTo(t.p));
      }
      worst = math.max(worst, best);
    }
    // the independent writer converted the coordinates with the same
    // three-parameter shift: agreement to millimetres
    expect(worst, lessThan(0.01));
  });

  test('compressed clouds, other files and damaged ones are refused with codes', () {
    expect(() => LasReader.read(fixture('las14_f6.laz')), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'las_laz_unsupported')));
    expect(() => LasReader.read(Uint8List.fromList([1, 2, 3, 4, 5])), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'las_not_las')));
    final bytes = fixture('las12_f0.las');
    final cut = LasReader.read(bytes.sublist(0, bytes.length - 2000));
    expect(cut.warnings.first, startsWith('las_truncated_points:'));
    final h = LasReader.readHeader(bytes);
    expect(h.pointCount, 756);
    expect(h.min.$1, greaterThanOrEqualTo(e0 - 1));
  });
}
