import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/model/boundary.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/lengthen.dart';
import 'package:opencadirrigation/core/model/split.dart';

/// The pure functions behind the drawing functions of 1.6.0 (CAD+): trim
/// with cuts at the ends only, Lengthen, the outline by a click inside.
void main() {
  group('trim', () {
    test('cuts that fall only on the ends trim nothing: the line stays whole', () {
      final line = LineEntity(id: 'l', a: Pt.zero, b: const Pt(10, 0));
      final pieces = trimLinearEntity(line, 5, [0, 10], () => 'x');
      expect(pieces, hasLength(1));
      expect(identical(pieces.single, line), isTrue);
      // a cut inside still trims
      expect(trimLinearEntity(line, 8, [0, 6, 10], () => 'x').single, isA<LineEntity>().having((l) => l.b.x, 'end', closeTo(6, 1e-9)));
    });
  });

  group('lengthen', () {
    test('a line grows or shrinks at the end nearest to the point, by a difference, to a total or by a percentage', () {
      final line = LineEntity(id: 'l', a: Pt.zero, b: const Pt(10, 0));
      final longer = lengthenEntity(line, const Pt(9, 0), LengthenMode.delta, 2)! as LineEntity;
      expect(longer.b.x, closeTo(12, 1e-9));
      expect(longer.a, Pt.zero);
      final shorter = lengthenEntity(line, const Pt(1, 0), LengthenMode.delta, -3)! as LineEntity;
      expect(shorter.a.x, closeTo(3, 1e-9));
      expect(shorter.b.x, closeTo(10, 1e-9));
      expect((lengthenEntity(line, const Pt(10, 0), LengthenMode.total, 25)! as LineEntity).b.x, closeTo(25, 1e-9));
      expect((lengthenEntity(line, const Pt(10, 0), LengthenMode.percent, 50)! as LineEntity).b.x, closeTo(5, 1e-9));
      expect(line.b.x, 10, reason: 'the item itself is not changed');
      // nothing left, or not a number
      expect(lengthenEntity(line, const Pt(10, 0), LengthenMode.delta, -10), isNull);
      expect(lengthenEntity(line, const Pt(10, 0), LengthenMode.total, 0), isNull);
      expect(lengthenEntity(line, const Pt(10, 0), LengthenMode.percent, double.nan), isNull);
    });

    test('a polyline grows along its end segment and is cut back along its path', () {
      final pl = PolylineEntity(id: 'p', points: [Pt.zero, const Pt(10, 0), const Pt(10, 10)]);
      final grown = lengthenEntity(pl, const Pt(10, 9), LengthenMode.delta, 5)! as PolylineEntity;
      expect(grown.points.last.y, closeTo(15, 1e-9));
      expect(grown.points, hasLength(3));
      final cut = lengthenEntity(pl, const Pt(10, 9), LengthenMode.total, 5)! as PolylineEntity;
      expect(cut.points.last.x, closeTo(5, 1e-9));
      expect(polylineLength(cut.points), closeTo(5, 1e-9));
      // at the start
      final start = lengthenEntity(pl, const Pt(0, 0), LengthenMode.delta, -12)! as PolylineEntity;
      expect(polylineLength(start.points), closeTo(8, 1e-9));
      expect(start.points.first.distanceTo(const Pt(10, 2)), lessThan(1e-9));
      expect(start.id, 'p');
      // a closed polyline has no end to move
      expect(lengthenEntity(PolylineEntity(id: 'q', points: [Pt.zero, const Pt(1, 0), const Pt(1, 1)], closed: true), Pt.zero, LengthenMode.delta, 1), isNull);
    });

    test('a spray lateral keeps its outlets where they were, and the pattern goes on into a part added at the start', () {
      final s = SpraylineEntity(id: 's', points: [Pt.zero, const Pt(20, 0)], outletSpecId: 'm', spacing: 4, offset: 2);
      final before = s.outletPositions();
      final grown = lengthenEntity(s, const Pt(0, 0), LengthenMode.delta, 7)! as SpraylineEntity;
      final after = grown.outletPositions();
      for (final p in before) {
        expect(after.any((q) => q.distanceTo(p) < 1e-6), isTrue, reason: '$p kept');
      }
      expect(after.first.x, closeTo(-6, 1e-6), reason: 'new outlets at the spacing before the old first one (…, -6, -2, 2, 6…)');
      final shrunk = lengthenEntity(s, const Pt(0, 0), LengthenMode.delta, -5)! as SpraylineEntity;
      for (final p in shrunk.outletPositions()) {
        expect(before.any((q) => q.distanceTo(p) < 1e-6), isTrue, reason: '$p was there');
      }
      expect(shrunk.outletPositions().first.x, closeTo(6, 1e-6));
    });

    test('an arc grows along its circle at the end nearest to the point', () {
      final a = ArcEntity(id: 'a', center: Pt.zero, radius: 10, startRad: 0, sweepRad: math.pi / 2);
      final longer = lengthenEntity(a, const Pt(0, 10), LengthenMode.delta, 10 * math.pi / 2)! as ArcEntity;
      expect(longer.sweepRad, closeTo(math.pi, 1e-9));
      expect(longer.startRad, closeTo(0, 1e-9));
      final atStart = lengthenEntity(a, const Pt(10, 0), LengthenMode.percent, 50)! as ArcEntity;
      expect(atStart.sweepRad, closeTo(math.pi / 4, 1e-9));
      expect(atStart.endPoint.distanceTo(a.endPoint), lessThan(1e-9), reason: 'the far end stays');
      // a whole circle is no arc
      expect(lengthenEntity(a, const Pt(0, 10), LengthenMode.total, 2 * math.pi * 10), isNull);
    });

    test('pipes, wires, tapes and contours lengthen; texts and areas do not', () {
      for (final e in [
        PipeEntity(id: 'p', points: [Pt.zero, const Pt(5, 0)], scope: HydraulicScope.zone),
        WireEntity(id: 'w', points: [Pt.zero, const Pt(5, 0)]),
        TapeEntity(id: 't', points: [Pt.zero, const Pt(5, 0)], tapeSpecId: 'x'),
        ContourEntity(id: 'c', points: [Pt.zero, const Pt(5, 0)], elevation: 100),
      ]) {
        final l = lengthenEntity(e, const Pt(5, 0), LengthenMode.delta, 1);
        expect(polylineLength(l!.linearPoints!), closeTo(6, 1e-9), reason: e.type.name);
        expect(l.runtimeType, e.runtimeType);
        final s = lengthenEntity(e, const Pt(5, 0), LengthenMode.delta, -1);
        expect(polylineLength(s!.linearPoints!), closeTo(4, 1e-9), reason: e.type.name);
      }
      expect(canLengthen(TextEntity(id: 'x', position: Pt.zero, text: 'a')), isFalse);
      expect(canLengthen(AreaEntity(id: 'x', points: [Pt.zero, const Pt(1, 0), const Pt(1, 1)])), isFalse);
    });
  });

  group('outline by a click inside', () {
    List<(Pt, Pt)> segs(List<Entity> es) => [for (final e in es) ...boundarySegments(CutEdge.of(e)!)];

    test('four crossing lines close a square around the point; the overhangs are pruned', () {
      final es = [
        LineEntity(id: '1', a: const Pt(-2, 0), b: const Pt(12, 0)),
        LineEntity(id: '2', a: const Pt(10, -2), b: const Pt(10, 12)),
        LineEntity(id: '3', a: const Pt(12, 10), b: const Pt(-2, 10)),
        LineEntity(id: '4', a: const Pt(0, 12), b: const Pt(0, -2)),
      ];
      final ring = boundaryAround(const Pt(5, 5), segs(es));
      expect(ring, isNotNull);
      expect(ring, hasLength(4));
      expect(polygonArea(ring!), closeTo(100, 1e-6));
      for (final c in const [Pt(0, 0), Pt(10, 0), Pt(10, 10), Pt(0, 10)]) {
        expect(ring.any((p) => p.distanceTo(c) < 1e-9), isTrue, reason: '$c');
      }
      // outside the square: no region
      expect(boundaryAround(const Pt(20, 20), segs(es)), isNull);
      // on a line: no region
      expect(boundaryAround(const Pt(5, 0), segs(es)), isNull);
    });

    test('the smallest region wins: a line across a rectangle splits it, a gap leaves no region', () {
      final rect = PolylineEntity(id: 'r', points: [Pt.zero, const Pt(20, 0), const Pt(20, 10), const Pt(0, 10)], closed: true);
      final across = LineEntity(id: 'x', a: const Pt(8, 0), b: const Pt(8, 10));
      final left = boundaryAround(const Pt(4, 5), segs([rect, across]))!;
      expect(polygonArea(left), closeTo(80, 1e-6));
      final right = boundaryAround(const Pt(15, 5), segs([rect, across]))!;
      expect(polygonArea(right), closeTo(120, 1e-6));
      // an open outline: no region
      final open = PolylineEntity(id: 'o', points: [Pt.zero, const Pt(20, 0), const Pt(20, 10), const Pt(0, 10), const Pt(0, 1)]);
      expect(boundaryAround(const Pt(4, 5), segs([open])), isNull);
      // ends within the tolerance meet
      expect(boundaryAround(const Pt(4, 5), segs([open, LineEntity(id: 'z', a: const Pt(0, 0.0000001), b: const Pt(0, 1.0000001))]), tol: 1e-3), isNotNull);
    });

    test('circles and arcs close regions; a shared side drawn twice is one side', () {
      final circle = CircleEntity(id: 'c', center: Pt.zero, radius: 5);
      final inCircle = boundaryAround(const Pt(1, 1), segs([circle]))!;
      expect(polygonArea(inCircle), closeTo(math.pi * 25, 0.5));
      // two squares side by side, the middle side drawn by both
      final a = PolylineEntity(id: 'a', points: [Pt.zero, const Pt(10, 0), const Pt(10, 10), const Pt(0, 10)], closed: true);
      final b = PolylineEntity(id: 'b', points: [const Pt(10, 0), const Pt(20, 0), const Pt(20, 10), const Pt(10, 10)], closed: true);
      expect(polygonArea(boundaryAround(const Pt(15, 5), segs([a, b]))!), closeTo(100, 1e-6));
      // a half-circle closed by its chord
      final half = ArcEntity(id: 'h', center: Pt.zero, radius: 10, startRad: 0, sweepRad: math.pi);
      final chord = LineEntity(id: 'k', a: const Pt(-10, 0), b: const Pt(10, 0));
      expect(polygonArea(boundaryAround(const Pt(0, 3), segs([half, chord]))!), closeTo(math.pi * 50, 2));
    });

    test('an island inside a region does not make a hole, and the point inside the island finds the island', () {
      final outer = PolylineEntity(id: 'o', points: [Pt.zero, const Pt(30, 0), const Pt(30, 30), const Pt(0, 30)], closed: true);
      final island = PolylineEntity(id: 'i', points: [const Pt(10, 10), const Pt(20, 10), const Pt(20, 20), const Pt(10, 20)], closed: true);
      expect(polygonArea(boundaryAround(const Pt(5, 5), segs([outer, island]))!), closeTo(900, 1e-6));
      expect(polygonArea(boundaryAround(const Pt(15, 15), segs([outer, island]))!), closeTo(100, 1e-6));
    });

    test('many lines: a grid of 60 × 60 lines finds its cell quickly', () {
      final es = <Entity>[
        for (var i = 0; i <= 60; i++) LineEntity(id: 'h$i', a: Pt(0, i * 1.0), b: Pt(60, i * 1.0)),
        for (var i = 0; i <= 60; i++) LineEntity(id: 'v$i', a: Pt(i * 1.0, 0), b: Pt(i * 1.0, 60)),
      ];
      final sw = Stopwatch()..start();
      final ring = boundaryAround(const Pt(30.5, 30.5), segs(es))!;
      expect(polygonArea(ring), closeTo(1, 1e-9));
      expect(sw.elapsedMilliseconds, lessThan(5000));
    });
  });
}
