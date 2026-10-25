import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/slope_map.dart';
import 'package:opencadirrigation/core/model/terrain.dart';

void main() {
  Terrain plane(double Function(double x, double y) z, {TerrainMethod method = TerrainMethod.tin}) {
    final t = Terrain(method: method);
    for (var i = 0; i <= 10; i++) {
      for (var j = 0; j <= 10; j++) {
        t.addSpot(Pt(i * 10.0, j * 10.0), z(i * 10.0, j * 10.0));
      }
    }
    return t;
  }

  test('a plane rising 10 % towards the east faces west everywhere', () {
    // the triangulation is exact on a plane; inverse distance terraces
    // between the samples, so it only gets close
    for (final method in TerrainMethod.values) {
      final tin = method == TerrainMethod.tin;
      final m = SlopeMap.compute(plane((x, y) => 0.1 * x, method: method), const Bounds(0, 0, 100, 100), maxCells: 400);
      expect(m.isEmpty, isFalse);
      var n = 0;
      for (var k = 0; k < m.slopePct.length; k++) {
        if (m.slopePct[k].isNaN) continue;
        n++;
        if (!tin) continue;
        expect(m.slopePct[k], closeTo(10, 0.05));
        expect(m.bearing[k], closeTo(270, 0.5));
      }
      expect(n, greaterThan(300));
      final (mean, max) = m.meanMax;
      expect(mean, closeTo(10, tin ? 0.05 : 3), reason: method.name);
      if (tin) {
        expect(m.classShares()[slopeClassOf(10)], closeTo(1, 1e-9));
        expect(max, closeTo(10, 0.05));
      }
    }
  });

  test('a plane falling to the north-east has a 45° bearing and pixels coloured by class', () {
    final m = SlopeMap.compute(plane((x, y) => -0.03 * x - 0.03 * y), const Bounds(0, 0, 100, 100), maxCells: 100);
    final k = m.slopePct.indexWhere((v) => !v.isNaN);
    expect(m.slopePct[k], closeTo(4.243, 0.01));
    expect(m.bearing[k], closeTo(45, 0.5));
    final px = slopeMapPixels(m);
    expect(px.length, m.nx * m.ny * 4);
    final c = slopeClasses[slopeClassOf(4.243)].$2;
    final row = m.ny - 1 - k ~/ m.nx, col = k % m.nx;
    final o = (row * m.nx + col) * 4;
    expect([px[o], px[o + 1], px[o + 2]], [(c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF]);
    final aspectPx = slopeMapPixels(m, aspect: true);
    expect(aspectPx[o + 3], greaterThan(0));
  });

  test('cells outside the hull of the samples are left out; empty terrain gives an empty map', () {
    final t = Terrain()
      ..addSpot(Pt.zero, 0)
      ..addSpot(const Pt(50, 0), 5)
      ..addSpot(const Pt(0, 50), 0);
    final m = SlopeMap.compute(t, const Bounds(0, 0, 50, 50), maxCells: 100);
    final mapped = m.slopePct.where((v) => !v.isNaN).length;
    expect(mapped, greaterThan(30));
    expect(mapped, lessThan(70)); // only the triangle, about half the square
    expect(SlopeMap.compute(Terrain(), const Bounds(0, 0, 10, 10)).isEmpty, isTrue);
  });

  test('slope classes, bearings and the convex hull', () {
    expect(slopeClassOf(0), 0);
    expect(slopeClassOf(1.99), 0);
    expect(slopeClassOf(2), 1);
    expect(slopeClassOf(80), slopeClasses.length - 1);
    expect(bearingDeg(0), closeTo(90, 1e-9)); // +x is east
    expect(bearingDeg(3.141592653589793 / 2), closeTo(0, 1e-9)); // +y is north
    expect(bearingDeg(-3.141592653589793 / 2), closeTo(180, 1e-9));
    final hull = convexHull([Pt.zero, const Pt(2, 0), const Pt(1, 1), const Pt(2, 2), const Pt(0, 2), const Pt(1, 0.5)]);
    expect(hull.toSet(), {Pt.zero, const Pt(2, 0), const Pt(2, 2), const Pt(0, 2)});
    expect(polygonArea(hull), closeTo(4, 1e-12));
  });
}
