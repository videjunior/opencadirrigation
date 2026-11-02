// Automatic design, layout geometry and the design assistant: the defects of
// the sweep of 1 November 2026 (AUT-01 … AUT-30), each with a test that
// failed before its correction, and the invariants every generator keeps.
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/block_generator.dart';
import 'package:opencadirrigation/core/design/tree_rings.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// Length (m) over which the polylines [a] and [b] run on top of each other
/// (collinear segments sharing a stretch).
double overlapLength(List<Pt> a, List<Pt> b) {
  var total = 0.0;
  for (var i = 1; i < a.length; i++) {
    for (var j = 1; j < b.length; j++) {
      final p = a[i - 1], q = a[i], r = b[j - 1], s = b[j];
      final d1 = q - p, d2 = s - r;
      if (d1.length < 1e-9 || d2.length < 1e-9) continue;
      if (d1.cross(d2).abs() > 1e-9 * d1.length * d2.length) continue;
      if ((r - p).cross(d1).abs() > 1e-6 * d1.length) continue;
      final t0 = (r - p).dot(d1) / d1.dot(d1), t1 = (s - p).dot(d1) / d1.dot(d1);
      final lo = (t0 < t1 ? t0 : t1).clamp(0.0, 1.0), hi = (t0 < t1 ? t1 : t0).clamp(0.0, 1.0);
      if (hi > lo) total += (hi - lo) * d1.length;
    }
  }
  return total;
}

/// Share of the rectangle [w] × [h] farther than [reach] from every line.
double uncovered(List<List<Pt>> lines, double w, double h, double reach) {
  var dry = 0, total = 0;
  for (var x = 1.0; x < w; x += 2) {
    for (var y = 1.0; y < h; y += 2) {
      final q = Pt(x, y);
      total++;
      var best = double.infinity;
      for (final l in lines) {
        for (var i = 1; i < l.length; i++) {
          final d = distanceToSegment(q, l[i - 1], l[i]);
          if (d < best) best = d;
        }
      }
      if (best > reach) dry++;
    }
  }
  return dry / total;
}

bool crossEachOther(List<List<Pt>> ls) {
  for (var i = 0; i < ls.length; i++) {
    for (var j = i + 1; j < ls.length; j++) {
      if (polylineIntersections(ls[i], ls[j]).any((x) => ls[i].every((q) => q.distanceTo(x) > 1e-6) && ls[j].every((q) => q.distanceTo(x) > 1e-6))) return true;
    }
  }
  return false;
}

void main() {
  group('AUT-01 guided blocks cover the whole polygon', () {
    const field = [Pt(0, 0), Pt(200, 0), Pt(200, 100), Pt(0, 100)];
    final guides = <String, List<Pt>>{
      'gentle contour': const [Pt(-10, 50), Pt(100, 60), Pt(210, 50)],
      'valley V': const [Pt(-10, 80), Pt(100, 20), Pt(210, 80)],
      'sharp valley V': const [Pt(-10, 95), Pt(100, 5), Pt(210, 95)],
      'contour over the middle only': const [Pt(50, 50), Pt(100, 56), Pt(150, 52)],
      'saw-tooth contour': [for (var i = 0; i <= 40; i++) Pt(-10 + 5.5 * i, 50 + 30 * (i < 20 ? 1 : -1) * (i % 20) / 20)],
    };
    for (final MapEntry(:key, :value) in guides.entries) {
      test(key, () {
        final p = Project();
        final r = generateBlock(p, BlockOptions(polygon: field, direction: const Pt(1, 0), lateralSpacing: 5, isTape: true, tapeSpecId: 'tape16', guide: value));
        final lines = [for (final e in r.laterals) (e as TapeEntity).points];
        expect(uncovered(lines, 200, 100, 5), lessThan(0.005), reason: 'every point within one lateral spacing of a lateral');
        final length = lines.fold(0.0, (s, l) => s + polylineLength(l));
        expect(length, closeTo(4000, 250), reason: 'about the field area over the spacing');
        expect(crossEachOther(lines), isFalse, reason: 'offset copies never cross');
        expect(r.messages, isEmpty);
        for (final l in lines) {
          for (final q in l) {
            expect(q.x, inInclusiveRange(-1e-6, 200 + 1e-6));
            expect(q.y, inInclusiveRange(-1e-6, 100 + 1e-6));
          }
        }
      });
    }

    test('a guide that cannot reach part of the polygon is reported', () {
      // a guide turning back on itself: the offsets of the hairpin stay
      // near it, the far corner of an L-shaped field is reached anyway or
      // reported, never silently dry
      const lField = [Pt(0, 0), Pt(120, 0), Pt(120, 40), Pt(40, 40), Pt(40, 120), Pt(0, 120)];
      final p = Project();
      final r = generateBlock(p, BlockOptions(polygon: lField, direction: const Pt(1, 0), lateralSpacing: 4, isTape: true, tapeSpecId: 'tape16', guide: const [Pt(-5, 20), Pt(125, 20)]));
      final lines = [for (final e in r.laterals) (e as TapeEntity).points];
      var dry = 0, inside = 0;
      for (var x = 1.0; x < 120; x += 2) {
        for (var y = 1.0; y < 120; y += 2) {
          if (!pointInPolygon(Pt(x, y), lField)) continue;
          inside++;
          var best = double.infinity;
          for (final l in lines) {
            for (var i = 1; i < l.length; i++) {
              best = best < distanceToSegment(Pt(x, y), l[i - 1], l[i]) ? best : distanceToSegment(Pt(x, y), l[i - 1], l[i]);
            }
          }
          if (best > 4) dry++;
        }
      }
      expect(dry / inside > guidedUncoveredLimit, r.messages.any((m) => m.startsWith('block_uncovered:')), reason: 'a dry share above the limit is always reported');
    });

    test('a mitre-limited offset of a hairpin stays near the line', () {
      const hairpin = [Pt(0, 0), Pt(200, 0), Pt(0, 2)];
      for (final d in [-17.5, 17.5]) {
        final off = offsetPolylineMitred(hairpin, d);
        final b = Bounds.ofPoints(off);
        expect(b.minX, greaterThan(-30), reason: 'd $d');
        expect(b.maxX, lessThan(200 + 17.5 + 1e-6), reason: 'no mitre spike beyond the turn (d $d)');
      }
    });
  });

  group('AUT-02 a row through a vertex of the polygon', () {
    List<double> rows(List<Pt> poly, double spacing, double first) {
      final p = Project();
      final r = generateBlock(p, BlockOptions(polygon: poly, direction: const Pt(1, 0), lateralSpacing: spacing, firstLateralOffset: first, isTape: true, tapeSpecId: 'tape16'));
      return ({for (final e in r.laterals) double.parse((e as TapeEntity).points.first.y.toStringAsFixed(3))}.toList()..sort());
    }

    test('a diamond with its side vertices on a row keeps that row', () {
      const diamond = [Pt(10, 0), Pt(20, 10), Pt(10, 20), Pt(0, 10)];
      expect(rows(diamond, 2, 2), [2, 4, 6, 8, 10, 12, 14, 16, 18]);
    });

    test('a hexagon keeps the row through its widest vertices', () {
      const hexagon = [Pt(5, 0), Pt(15, 0), Pt(20, 10), Pt(15, 20), Pt(5, 20), Pt(0, 10)];
      expect(rows(hexagon, 1.5, 1), contains(10.0));
      expect(rows(hexagon, 1.5, 1).length, 13);
    });
  });

  group('AUT-14 a centre submain keeps its stub off the laterals', () {
    for (final vp in ValvePosition.values) {
      for (final n in [6, 5]) {
        test('valve ${vp.name}, $n rows', () {
          final p = Project();
          final h = n * 5.0;
          final b = generateBlock(
            p,
            BlockOptions(
              polygon: [const Pt(0, 0), const Pt(60, 0), Pt(60, h), Pt(0, h)],
              direction: const Pt(1, 0),
              lateralSpacing: 5,
              outletSpecId: 'micro',
              nozzleId: 'm50',
              outletSpacing: 3,
              headM: 15,
              submainPosition: SubmainPosition.centre,
              valvePosition: vp,
              submainStub: 1.5,
              valveSpecId: 'ev50',
              zoneName: 'A',
            ),
          );
          final stub = b.stub!.points;
          for (final l in b.laterals) {
            expect(overlapLength(stub, (l as PolyEntity).points), 0, reason: 'the stub lies on no lateral');
            expect(distanceToSegment(b.valve!.position, l.points.first, l.points.last), greaterThan(0.5), reason: 'the valve stands off the laterals');
          }
          if (vp != ValvePosition.centre) {
            final y = b.valve!.position.y;
            expect(y < 2.5 || y > h - 2.5, isTrue, reason: 'at an end of the submain the valve stands beyond the outer rows, on the submain line');
            expect(b.valve!.position.x, closeTo(30, 1e-9));
          }
        });
      }
    }
  });

  group('AUT-15 tree rings fed from the centre with an odd count a row', () {
    for (final w in [30.0, 36.0]) {
      test('width $w', () {
        final area = [const Pt(0, 0), Pt(w, 0), Pt(w, 21), const Pt(0, 21)];
        final l = layoutTreeRings(
          area: area,
          options: TreeRingOptions(plantSpacing: 6, rowSpacing: 7, submainPosition: SubmainPosition.centre),
        );
        for (var i = 0; i < l.laterals.length; i++) {
          for (var j = i + 1; j < l.laterals.length; j++) {
            expect(overlapLength(l.laterals[i], l.laterals[j]), lessThan(1e-6), reason: 'laterals $i and $j');
          }
          final pts = l.laterals[i];
          for (var k = 2; k < pts.length; k++) {
            final a = pts[k - 1] - pts[k - 2], b = pts[k] - pts[k - 1];
            expect(a.dot(b), greaterThan(0), reason: 'lateral $i never turns back at vertex ${k - 1}');
          }
        }
        for (final t in l.trees) {
          expect(l.submain.every((q) => q.distanceTo(t) > 0.6), isTrue, reason: 'the submain passes no trunk');
        }
      });
    }
  });
}
