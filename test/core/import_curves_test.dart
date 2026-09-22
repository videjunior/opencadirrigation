import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/io/dwg.dart';
import 'package:opencadirrigation/core/io/dxf.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// DXF text from (code, value) pairs.
String _dxf(List<(int, Object)> entities, {List<(int, Object)> blocks = const []}) {
  final b = StringBuffer();
  void p(int c, Object v) => b
    ..writeln(c)
    ..writeln(v);
  if (blocks.isNotEmpty) {
    p(0, 'SECTION');
    p(2, 'BLOCKS');
    for (final (c, v) in blocks) {
      p(c, v);
    }
    p(0, 'ENDSEC');
  }
  p(0, 'SECTION');
  p(2, 'ENTITIES');
  for (final (c, v) in entities) {
    p(c, v);
  }
  p(0, 'ENDSEC');
  p(0, 'EOF');
  return b.toString();
}

void main() {
  group('NURBS', () {
    test('a rational quadratic quarter circle stays on the circle', () {
      final w = math.sqrt(2) / 2;
      final pts = nurbsCurve(2, const [Pt(1, 0), Pt(1, 1), Pt(0, 1)], knots: const [0, 0, 0, 1, 1, 1], weights: [1, w, 1], samples: 20);
      expect(pts.length, 20);
      expect(pts.first.distanceTo(const Pt(1, 0)), lessThan(1e-12));
      expect(pts.last.distanceTo(const Pt(0, 1)), lessThan(1e-12));
      for (final q in pts) {
        expect(q.length, closeTo(1, 1e-12));
      }
    });

    test('a clamped cubic ends on its end points; bad knots fall back to a uniform vector', () {
      const ctrl = [Pt(0, 0), Pt(1, 2), Pt(3, 2), Pt(4, 0)];
      final a = nurbsCurve(3, ctrl, knots: const [0, 0, 0, 0, 1, 1, 1, 1]);
      final b = nurbsCurve(3, ctrl, knots: const [1, 2]); // wrong length
      expect(a.first, const Pt(0, 0));
      expect(a.last.distanceTo(const Pt(4, 0)), lessThan(1e-12));
      expect(b.last.distanceTo(const Pt(4, 0)), lessThan(1e-12));
      expect(a.length, 32);
      // Bézier midpoint of a symmetric cubic
      final mid = nurbsCurve(3, ctrl, knots: const [0, 0, 0, 0, 1, 1, 1, 1], samples: 3)[1];
      expect(mid.x, closeTo(2, 1e-12));
      expect(mid.y, closeTo(1.5, 1e-12));
      expect(nurbsCurve(3, const []), isEmpty);
      // degree clamped to 1: the straight segment
      final line = nurbsCurve(3, const [Pt(1, 1), Pt(2, 2)]);
      expect(line, hasLength(16));
      expect(line.every((q) => (q.x - q.y).abs() < 1e-12), isTrue);
    });
  });

  group('DXF', () {
    test('a control-point SPLINE is evaluated, not taken as its control polygon', () {
      final w = math.sqrt(2) / 2;
      final doc = DxfReader.parse(_dxf([
        (0, 'SPLINE'), (8, 'S'), (70, 4), (71, 2), (72, 6), (73, 3),
        for (final k in [0, 0, 0, 1, 1, 1]) (40, k),
        (10, 1), (20, 0), (30, 0), (41, 1),
        (10, 1), (20, 1), (30, 0), (41, w),
        (10, 0), (20, 1), (30, 0), (41, 1),
      ]));
      final e = doc.entities.single;
      expect(e.type, 'POLYLINE');
      expect(e.points.length, greaterThan(8));
      for (final q in e.points) {
        expect(q.length, closeTo(1, 1e-9));
      }
    });

    test('a SPLINE with fit points becomes a smooth spline through them', () {
      final doc = DxfReader.parse(_dxf([
        (0, 'SPLINE'), (8, 'S'), (70, 0), (71, 3), (74, 3),
        (11, 0), (21, 0), (31, 0), (11, 5), (21, 3), (31, 0), (11, 10), (21, 0), (31, 0),
      ]));
      final e = doc.entities.single;
      expect(e.type, 'SPLINE');
      expect(e.points, const [Pt(0, 0), Pt(5, 3), Pt(10, 0)]);
      final c = ProjectController(store: null)..autosaveEnabled = false;
      c.importDrawing(doc);
      final s = c.project.entities.whereType<SplineEntity>().single;
      expect(s.points.length, 3);
      expect(s.curve().length, greaterThan(3));
    });

    test('HATCH: polyline path with bulge, edge path with line and arc, pattern spacing', () {
      final doc = DxfReader.parse(_dxf([
        // square 10 × 10 with a 45° ANSI-like pattern of 2.5 spacing
        (0, 'HATCH'), (8, 'H'), (2, 'ANSI31'), (70, 0), (71, 0), (91, 1),
        (92, 3), (72, 0), (73, 1), (93, 4), (10, 0), (20, 0), (10, 10), (20, 0), (10, 10), (20, 10), (10, 0), (20, 10), (97, 0),
        (75, 0), (76, 1), (52, 0), (41, 1), (77, 0), (78, 1), (53, 45), (43, 0), (44, 0), (45, -1.767767), (46, 1.767767), (79, 0), (98, 0),
        // half disc: diameter line then a counter-clockwise arc, solid
        (0, 'HATCH'), (8, 'H'), (2, 'SOLID'), (70, 1), (71, 0), (91, 1),
        (92, 1), (93, 2), (72, 1), (10, -5), (20, 20), (11, 5), (21, 20), (72, 2), (10, 0), (20, 20), (40, 5), (50, 0), (51, 180), (73, 1), (97, 0),
        (75, 0), (76, 1), (98, 0),
      ]));
      final hs = doc.entities.where((e) => e.type == 'HATCH').toList();
      expect(hs.length, 2);
      final sq = hs.first;
      expect(sq.solid, isFalse);
      expect(sq.points.length, 4);
      expect(polygonArea(sq.points).abs(), closeTo(100, 1e-9));
      expect(sq.rotation, 45);
      expect(sq.height, closeTo(2.5, 1e-5));
      final disc = hs.last;
      expect(disc.solid, isTrue);
      expect(polygonArea(disc.points).abs(), closeTo(math.pi * 25 / 2, 0.3));
      expect(disc.points.every((q) => q.y >= 20 - 1e-9), isTrue, reason: 'the arc bulges upwards');
      final c = ProjectController(store: null)..autosaveEnabled = false;
      c.importDrawing(doc);
      final imported = c.project.entities.whereType<HatchEntity>().toList();
      expect(imported.length, 2);
      expect(imported.first.spacing, closeTo(2.5, 1e-5));
      expect(imported.first.angleDeg, 45);
      expect(imported.last.solid, isTrue);
    });

    test('HATCH: clockwise arcs, ellipse and spline edges, islands', () {
      final doc = DxfReader.parse(_dxf([
        (0, 'HATCH'), (8, 'H'), (2, 'SOLID'), (70, 1), (71, 0), (91, 2),
        // outer: a full ellipse 20 × 10
        (92, 1), (93, 1), (72, 3), (10, 0), (20, 0), (11, 10), (21, 0), (40, 0.5), (50, 0), (51, 360), (73, 1), (97, 0),
        // island: clockwise half circle closed by a line
        (92, 16), (93, 2), (72, 2), (10, 0), (20, 0), (40, 2), (50, 0), (51, 180), (73, 0), (72, 1), (10, -2), (20, 0), (11, 2), (21, 0), (97, 0),
        (75, 0), (76, 1), (98, 0),
        // a spline edge (quadratic Bézier) closed by a line
        (0, 'HATCH'), (8, 'H'), (2, 'SOLID'), (70, 1), (71, 0), (91, 1),
        (92, 1), (93, 2),
        (72, 4), (94, 2), (73, 0), (74, 0), (95, 6), (96, 3), (40, 0), (40, 0), (40, 0), (40, 1), (40, 1), (40, 1), (10, 0), (20, 30), (10, 5), (20, 40), (10, 10), (20, 30),
        (72, 1), (10, 10), (20, 30), (11, 0), (21, 30), (97, 0),
        (75, 0), (76, 1), (98, 0),
      ]));
      final hatches = doc.entities.where((e) => e.type == 'HATCH').toList();
      expect(hatches.length, 2);
      expect(polygonArea(hatches.first.points).abs(), closeTo(math.pi * 10 * 5, 1));
      final island = doc.entities.where((e) => e.type == 'POLYLINE').single;
      expect(island.closed, isTrue);
      // clockwise from 0° to -180°: the half below the x axis
      expect(island.points.every((q) => q.y <= 1e-9), isTrue);
      expect(polygonArea(island.points).abs(), closeTo(math.pi * 4 / 2, 0.1));
      final bez = hatches.last;
      expect(bez.points.map((q) => q.y).reduce(math.max), closeTo(35, 0.05));
    });

    test('SOLID and TRACE become solid hatches; hatches in blocks are placed', () {
      final doc = DxfReader.parse(_dxf([
        (0, 'SOLID'), (8, 'S'), (10, 0), (20, 0), (11, 4), (21, 0), (12, 0), (22, 3), (13, 4), (23, 3),
        (0, 'TRACE'), (8, 'S'), (10, 0), (20, 10), (11, 1), (21, 10), (12, 0), (22, 11), (13, 0), (23, 11),
        (0, 'INSERT'), (8, 'B'), (2, 'BLK'), (10, 100), (20, 0), (41, 2), (42, 2), (50, 90),
      ], blocks: [
        (0, 'BLOCK'), (8, '0'), (2, 'BLK'), (10, 0), (20, 0),
        (0, 'HATCH'), (8, '0'), (2, 'ANSI31'), (70, 0), (91, 1), (92, 3), (72, 0), (73, 1), (93, 3), (10, 0), (20, 0), (10, 1), (20, 0), (10, 0), (20, 1), (97, 0), (75, 0), (76, 1), (52, 0), (41, 1), (78, 1), (53, 0), (43, 0), (44, 0), (45, 0), (46, 1), (79, 0), (98, 0),
        (0, 'ENDBLK'),
      ]));
      final solids = doc.entities.where((e) => e.type == 'HATCH' && e.solid).toList();
      expect(solids.length, 2);
      // 1-2-4-3 order: a proper rectangle, not a bow tie
      expect(polygonArea(solids.first.points).abs(), closeTo(12, 1e-9));
      expect(solids.last.points.length, 3); // TRACE with two equal corners
      final placed = doc.entities.where((e) => e.type == 'HATCH' && !e.solid).single;
      expect(placed.layer, 'B');
      expect(placed.points[1].distanceTo(const Pt(100, 2)), lessThan(1e-9));
      expect(placed.rotation, closeTo(90, 1e-9));
      expect(placed.height, closeTo(2, 1e-9));
    });
  });

  group('DWG', () {
    for (final v in ['2000', '2004', '2007', '2010', '2013', '2018']) {
      test('example_$v: splines, hatches, solids and the ellipse like LibreDWG reads them', () {
        final r = DwgReader.parse(File('test/fixtures/example_$v.dwg').readAsBytesSync());
        final doc = r.document;
        final splines = doc.entities.where((e) => e.type == 'SPLINE').toList();
        expect(splines.length, 2);
        // fit points (LibreDWG: first -1160.708, 1466.300, six points)
        expect(splines.first.points.length, 6);
        expect(splines.first.points.first.distanceTo(const Pt(-1160.70828949499, 1466.2995980182498)), lessThan(1e-6));
        expect(splines.last.points.last.distanceTo(const Pt(-1541.918454872604, 2698.7729663766513)), lessThan(1e-6));
        final pattern = doc.entities.where((e) => e.type == 'HATCH' && !e.solid).single;
        expect(pattern.points.length, 6);
        expect(pattern.points.first.distanceTo(const Pt(1403.271282119223, 1189.0093796636304)), lessThan(1e-6));
        expect(pattern.height, closeTo(13.97, 1e-9));
        expect(doc.entities.where((e) => e.type == 'HATCH' && e.solid).length, 19);
        // the ellipse: centre + semi-major axis is its first point
        final ellipse = doc.entities.where((e) => e.type == 'POLYLINE' && e.closed && e.points.length == 36).toList();
        expect(ellipse.any((e) => e.points.first.distanceTo(const Pt(3532.1668210255702 - 1220.8656432199095, 2904.2609165161084 + 355.80176036963894)) < 1e-6), isTrue);
      });
    }
  });
}
