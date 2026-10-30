import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/region_trace.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// A synthetic aerial picture: [w] × [h] RGBA pixels of 0.5 m, coloured by
/// [paint] (x, y in pixels from the top-left corner → [r, g, b] or null for
/// no imagery), with noise.
class _Picture {
  _Picture(this.w, this.h, List<int>? Function(int x, int y) paint, {int noise = 10, int seed = 1}) : rgba = Uint8List(4 * w * h) {
    final rnd = math.Random(seed);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = 4 * (y * w + x);
        final c = paint(x, y);
        if (c == null) continue;
        for (var k = 0; k < 3; k++) {
          rgba[i + k] = (c[k] + rnd.nextInt(2 * noise + 1) - noise).clamp(0, 255);
        }
        rgba[i + 3] = 255;
      }
    }
  }
  final int w, h;
  final Uint8List rgba;
  static const pixelM = 0.5;
  Pt toWorld(double x, double y) => Pt(x * pixelM, (h - y) * pixelM);

  RegionTrace trace(double x, double y, {RegionTraceOptions o = const RegionTraceOptions()}) => traceRegion(rgba, w, h, seedX: x, seedY: y, pixelM: pixelM, toWorld: toWorld, o: o);
}

const _soil = [130, 100, 70], _road = [175, 172, 160], _tree = [28, 58, 24];

/// A crop with darker rows every 3 pixels (1.5 m), as on a satellite image.
List<int> _crop(int x, int y) => x % 3 == 0 ? const [40, 108, 36] : const [62, 140, 52];

void main() {
  test('a field with crop rows: traced to its edges, not into the field of the same crop across the road', () {
    // field A: x 50–250, y 40–200; a 5-pixel road; field B of the same crop beyond it
    final pic = _Picture(400, 300, (x, y) {
      if (y >= 40 && y < 200) {
        if (x >= 50 && x < 250) return _crop(x, y);
        if (x >= 250 && x < 255) return _road;
        if (x >= 255 && x < 380) return _crop(x, y);
      }
      return _soil;
    });
    final r = pic.trace(150, 120);
    const expected = 200 * 160 * 0.25; // m²
    expect(r.automatic, isTrue);
    expect(r.clearBoundary, isTrue, reason: 'the area stops growing at the field edge');
    expect(r.touchesEdge, isFalse);
    expect(r.areaM2, closeTo(expected, 0.04 * expected), reason: 'not across the road into field B');
    final poly = polygonArea(r.outline);
    expect(poly, greaterThan(0), reason: 'counter-clockwise');
    expect(poly, closeTo(expected, 0.05 * expected));
    final b = Bounds.ofPoints(r.outline);
    expect(b.minX, closeTo(25, 1.5));
    expect(b.maxX, closeTo(125, 1.5));
    expect(b.minY, closeTo(50, 1.5));
    expect(b.maxY, closeTo(130, 1.5));
    expect(r.outline.length, lessThan(40), reason: 'simplified: a rectangle needs few vertices');
    expect(r.leakTolerance, isNotNull, reason: 'the text says where it would leak');
    expect(r.leakTolerance!, greaterThan(r.tolerance));
  });

  test('a tree inside the field: the hole is filled and reported with its outline', () {
    final pic = _Picture(300, 300, (x, y) {
      if ((x - 150) * (x - 150) + (y - 150) * (y - 150) <= 10 * 10) return _tree;
      if (x >= 60 && x < 240 && y >= 60 && y < 240) return _crop(x, y);
      return _soil;
    });
    final r = pic.trace(100, 100);
    const field = 180 * 180 * 0.25;
    expect(r.areaM2, closeTo(field, 0.04 * field), reason: 'the hole filled');
    expect(r.holeCount, 1);
    expect(r.holes, hasLength(1));
    expect(r.holeAreaM2, closeTo(math.pi * 100 * 0.25, 25));
    final hb = Bounds.ofPoints(r.holes.first);
    expect(hb.center.x, closeTo(75, 1.5));
    expect(hb.center.y, closeTo(75, 1.5));
  });

  test('a field running off the picture is flagged; a set tolerance and no imagery behave', () {
    final pic = _Picture(200, 200, (x, y) => x < 20 ? null : (x >= 120 ? _crop(x, y) : _soil));
    final r = pic.trace(160, 100);
    expect(r.touchesEdge, isTrue, reason: 'the field reaches the right, top and bottom edges');
    expect(r.areaM2, closeTo(80 * 200 * 0.25, 0.05 * 80 * 200 * 0.25));
    // a tiny tolerance keeps only the pixels next to the reference colour
    final tight = pic.trace(160, 100, o: const RegionTraceOptions(tolerance: 1));
    expect(tight.automatic, isFalse);
    expect(tight.areaM2, lessThan(r.areaM2));
    expect(() => pic.trace(5, 100), throwsA(isA<RegionTraceError>()), reason: 'no imagery there');
    expect(() => pic.trace(250, 100), throwsA(isA<RegionTraceError>()), reason: 'outside the picture');
    expect(r.touchesNoData, isFalse);
    // the soil strip next to the missing imagery reaches it
    final soil = pic.trace(60, 100);
    expect(soil.touchesNoData, isTrue);
  });

  test('a seed on the boundary shows a large spread', () {
    final pic = _Picture(200, 200, (x, y) => x < 100 ? _soil : _crop(x, y), noise: 4);
    final inside = pic.trace(150, 100), edge = pic.trace(100, 100);
    expect(edge.seedSpread, greaterThan(3 * inside.seedSpread + 1));
  });

  test('every field of a picture: found and outlined, roads, specks and fields cut by the edge left out', () async {
    // 0.5 m pixels: three fields of different crops between roads, a small
    // tree, a field cut by the right edge
    const fieldA = [62, 140, 52], fieldB = [150, 160, 70], fieldC = [40, 90, 40];
    List<int> rows(List<int> c, int x) => x % 3 == 0 ? [c[0] - 18, c[1] - 30, c[2] - 14] : c;
    final pic = _Picture(640, 400, (x, y) {
      if (y >= 190 && y < 200) return _road; // a road across
      if (x >= 300 && x < 310) return _road; // and one along
      if ((x - 150) * (x - 150) + (y - 330) * (y - 330) <= 36) return _tree;
      if (x >= 40 && x < 280 && y >= 30 && y < 180) return rows(fieldA, x); // 240 × 150 px
      if (x >= 330 && x < 560 && y >= 30 && y < 180) return rows(fieldB, x); // 230 × 150 px
      if (x >= 40 && x < 280 && y >= 215 && y < 380) return rows(fieldC, x); // 240 × 165 px
      if (x >= 520 && y >= 215 && y < 380) return rows(fieldA, x); // cut by the right edge
      return _soil;
    });
    final r = await traceRegions(pic.rgba, pic.w, pic.h, pixelM: _Picture.pixelM, toWorld: pic.toWorld);
    final expected = [240 * 150 * 0.25, 230 * 150 * 0.25, 240 * 165 * 0.25];
    // the soil between them is one more region: match the fields by their centres
    final centres = [const Pt(80, 147.5), const Pt(222.5, 147.5), const Pt(80, 51.25)];
    for (var k = 0; k < 3; k++) {
      final m = r.regions.where((g) => pointInPolygon(centres[k], g.outline)).toList();
      expect(m, isNotEmpty, reason: 'field ${k + 1} found');
      final g = m.reduce((a, b) => a.areaM2 < b.areaM2 ? a : b);
      expect(g.areaM2, closeTo(expected[k], 0.05 * expected[k]), reason: 'field ${k + 1}');
      expect(polygonArea(g.outline), greaterThan(0));
      expect(g.touchesEdge, isFalse);
    }
    for (final g in r.regions) {
      expect(g.areaM2, greaterThanOrEqualTo(2000));
      expect(g.meanWidthM, greaterThanOrEqualTo(10), reason: 'no road among the regions');
      expect(g.touchesEdge, isFalse, reason: 'the cut field is left out');
    }
    expect(r.edge, greaterThanOrEqualTo(1), reason: 'the field cut by the edge');
    // seeds every 2.5 m land on the roads and the tree too: left out
    final dense = await traceRegions(pic.rgba, pic.w, pic.h, pixelM: _Picture.pixelM, toWorld: pic.toWorld, o: const RegionsOptions(seedSpacingM: 2.5));
    expect(dense.thin, greaterThanOrEqualTo(1), reason: 'the roads');
    expect(dense.small, greaterThanOrEqualTo(1), reason: 'the tree');
    expect(dense.regions.length, r.regions.length, reason: 'the same fields');
    // with the edge allowed the cut field comes too
    final all = await traceRegions(pic.rgba, pic.w, pic.h, pixelM: _Picture.pixelM, toWorld: pic.toWorld, o: const RegionsOptions(includeEdge: true));
    expect(all.regions.any((g) => g.touchesEdge && pointInPolygon(const Pt(300, 50), g.outline)), isTrue);
  });

  test('wide rows: a box over the rows outlines the whole field from a point on any row', () {
    // rows 5 px (2.5 m) dark, 5 px light
    final pic = _Picture(300, 260, (x, y) => x >= 50 && x < 250 && y >= 50 && y < 210 ? ((x ~/ 5).isEven ? const [36, 96, 32] : const [70, 150, 58]) : _soil, noise: 6);
    const expected = 200 * 160 * 0.25;
    for (final x in [102.5, 107.5, 152.5, 157.5]) {
      final r = pic.trace(x, 130, o: const RegionTraceOptions(blurM: 5, seedRadiusM: 1));
      expect(r.areaM2, closeTo(expected, 0.05 * expected), reason: 'seed at x $x');
    }
  });
}
