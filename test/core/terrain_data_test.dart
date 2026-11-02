import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/terrain.dart';
import 'package:opencadirrigation/core/model/tin.dart';

/// Inverse distance over the [k] nearest samples found by brute force: the
/// reference the grid search must match.
double bruteIdw(Terrain t, Pt p, int k) {
  final s = [...t.samples]..sort((a, b) => a.p.distanceTo(p).compareTo(b.p.distanceTo(p)));
  if (s.first.p.distanceTo(p) < 1e-9) return s.first.z;
  var num = 0.0, den = 0.0;
  for (final x in s.take(k)) {
    final w = 1 / math.pow(x.p.distanceTo(p), 2);
    num += w * x.z;
    den += w;
  }
  return num / den;
}

/// Contours every metre on a 5 % slope over x = 0…200 m (100 + 0.05 x).
Terrain slope({TerrainMethod method = TerrainMethod.idw}) {
  final t = Terrain(method: method);
  for (var z = 0; z <= 10; z++) {
    t.addContour([Pt(z / 0.05, 0), Pt(z / 0.05, 200)], 100.0 + z);
  }
  return t;
}

void main() {
  group('IDW nearest samples (MOD-01)', () {
    test('far outside the data it averages the true nearest samples', () {
      final t = slope();
      // 150 m beyond the 100 m contour: its samples are the nearest ones
      expect(t.idwAt(const Pt(-150, 100)), closeTo(100, 1e-9));
      expect(slope(method: TerrainMethod.tin).elevationAt(const Pt(-150, 100)), closeTo(100, 1e-9), reason: 'the TIN falls back to IDW outside its hull');
      expect(t.idwAt(const Pt(400, 100)), closeTo(110, 1e-9));
    });

    test('matches a brute-force search inside and outside the hull', () {
      final t = slope();
      final rnd = math.Random(3);
      for (var i = 0; i < 1500; i++) {
        final p = Pt(-400 + rnd.nextDouble() * 1000, -400 + rnd.nextDouble() * 1000);
        expect(t.idwAt(p), closeTo(bruteIdw(t, p, 8), 1e-9), reason: '$p');
      }
      for (var i = 0; i < 500; i++) {
        final p = Pt(rnd.nextDouble() * 200, rnd.nextDouble() * 200);
        expect(t.idwAt(p), closeTo(bruteIdw(t, p, 8), 1e-9), reason: '$p');
      }
      // fewer samples than neighbours, a single sample, a sample on the point
      final few = Terrain(method: TerrainMethod.idw)
        ..addSpot(const Pt(0, 0), 10)
        ..addSpot(const Pt(10, 0), 20);
      expect(few.idwAt(const Pt(5, 50)), closeTo(15, 1e-9));
      expect(few.idwAt(const Pt(10, 0)), 20);
      expect((Terrain()..addSpot(const Pt(3, 4), 7)).idwAt(const Pt(1000, -1000)), 7);
      expect(Terrain().idwAt(Pt.zero, fallback: -1), -1);
    });

    test('a hydraulic item far outside the survey is reported', () {
      final t = slope();
      expect(t.extrapolatesAt(const Pt(100, 100)), isFalse);
      expect(t.extrapolatesAt(const Pt(-150, 100), margin: 10), isTrue);
      expect(t.extrapolatesAt(const Pt(-5, 100), margin: 10), isFalse, reason: 'within the margin');
      expect(Terrain().extrapolatesAt(Pt.zero), isFalse, reason: 'no data, nothing extrapolated');
      final line = Terrain()
        ..addSpot(const Pt(0, 0), 1)
        ..addSpot(const Pt(10, 0), 2);
      expect(line.extrapolatesAt(const Pt(5, 0.5), margin: 1), isFalse);
      expect(line.extrapolatesAt(const Pt(5, 30), margin: 1), isTrue);
    });
  });

  group('TIN of large terrains (MOD-12, MOD-13)', () {
    test('the surveyed points stay in the TIN; only the downloaded model is thinned', () {
      final rnd = math.Random(7);
      final t = Terrain(tinLimit: 12000);
      for (var i = 0; i < 150; i++) {
        for (var j = 0; j < 100; j++) {
          t.addSpot(Pt(i * 10.0, j * 10.0), 100, dem: true);
        }
      }
      final survey = [for (var k = 0; k < 40; k++) Pt(600 + rnd.nextDouble() * 100, 400 + rnd.nextDouble() * 100)];
      for (final s in survey) {
        t.addSpot(s, 102);
      }
      expect(t.sampleCount, 15040);
      expect(t.tinSampleCount, lessThanOrEqualTo(12000));
      expect(t.tinSampleCount, greaterThan(10000));
      for (final s in survey) {
        expect(t.elevationAt(s), closeTo(102, 1e-6), reason: '$s');
      }
      // the model keeps covering the whole area evenly
      expect(t.tin.elevationAt(const Pt(5, 5)), isNotNull);
      expect(t.tin.elevationAt(const Pt(1485, 985)), isNotNull);
    });

    test('a survey larger than the limit is spread over its extent', () {
      final t = Terrain(tinLimit: 500);
      for (var i = 0; i < 40; i++) {
        for (var j = 0; j < 40; j++) {
          t.addSpot(Pt(i * 5.0, j * 5.0), 100 + i * 0.1 + j * 0.2);
        }
      }
      expect(t.tinSampleCount, inInclusiveRange(400, 500));
      expect(t.tin.elevationAt(const Pt(2, 2)), isNotNull, reason: 'corners kept');
      expect(t.tin.elevationAt(const Pt(193, 193)), isNotNull);
    });

    test('Bowyer-Watson with a walk: tens of thousands of points in well under a second each', () {
      final rnd = math.Random(5);
      final pts = [for (var i = 0; i < 40000; i++) (rnd.nextDouble() * 1000, rnd.nextDouble() * 1000, rnd.nextDouble() * 10)];
      final sw = Stopwatch()..start();
      final tin = Tin.build(pts);
      expect(sw.elapsedMilliseconds, lessThan(8000));
      expect(tin.triangles.length, greaterThan(79000));
      // still a Delaunay triangulation: no point inside a triangle's circle
      for (var k = 0; k < tin.triangles.length; k += 997) {
        final tr = tin.triangles[k];
        final a = tin.vertex(tr.a), b = tin.vertex(tr.b), c = tin.vertex(tr.c);
        final d = 2 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y));
        final ux = ((a.x * a.x + a.y * a.y) * (b.y - c.y) + (b.x * b.x + b.y * b.y) * (c.y - a.y) + (c.x * c.x + c.y * c.y) * (a.y - b.y)) / d;
        final uy = ((a.x * a.x + a.y * a.y) * (c.x - b.x) + (b.x * b.x + b.y * b.y) * (a.x - c.x) + (c.x * c.x + c.y * c.y) * (b.x - a.x)) / d;
        final r = a.distanceTo(Pt(ux, uy));
        for (var i = 0; i < pts.length; i += 41) {
          final q = Pt(pts[i].$1, pts[i].$2);
          expect(q.distanceTo(Pt(ux, uy)), greaterThan(r * (1 - 1e-7)), reason: 'triangle $k');
        }
      }
    });

    test('regular grids and co-circular points keep their diagonals', () {
      final grid = Tin.build([
        for (var i = 0; i < 3; i++)
          for (var j = 0; j < 3; j++) (i * 10.0, j * 10.0, 0.0),
      ]);
      expect(grid.triangles.length, 8);
      final circle = Tin.build([for (var i = 0; i < 16; i++) (math.cos(i * math.pi / 8) * 50, math.sin(i * math.pi / 8) * 50, 1.0)]);
      expect(circle.triangles.length, 14);
    });

    test('the project keeps its terrain until the terrain data change', () {
      final p = Project();
      p.entities.add(SpotHeightEntity(id: p.newId(), position: const Pt(0, 0), elevation: 10));
      p.entities.add(SpotHeightEntity(id: p.newId(), position: const Pt(100, 0), elevation: 20));
      p.entities.add(SpotHeightEntity(id: p.newId(), position: const Pt(0, 100), elevation: 30));
      final a = p.buildTerrain();
      expect(identical(p.buildTerrain(), a), isTrue);
      p.entities.add(LineEntity(id: p.newId(), a: Pt.zero, b: const Pt(5, 5)));
      expect(identical(p.buildTerrain(), a), isTrue, reason: 'a drawing line is no terrain datum');
      (p.entities.first as SpotHeightEntity).elevation = 12;
      final b = p.buildTerrain();
      expect(identical(b, a), isFalse);
      expect(b.elevationAt(Pt.zero), closeTo(12, 1e-9));
      p.params.terrainMethod = TerrainMethod.idw;
      expect(p.buildTerrain().method, TerrainMethod.idw);
    });

    test('unknown elevations are no data, not 0 m', () {
      final t = Terrain()
        ..addSpot(const Pt(0, 0), 800)
        ..addSpot(const Pt(10, 0), 800)
        ..addSpot(const Pt(0, 10), 800)
        ..addSpot(const Pt(3, 3), double.nan)
        ..addContour(const [Pt(-5, 0), Pt(-5, 10)], double.nan);
      expect(t.sampleCount, 3);
      expect(t.elevationAt(const Pt(3, 3)), closeTo(800, 1e-9));
    });
  });
}
