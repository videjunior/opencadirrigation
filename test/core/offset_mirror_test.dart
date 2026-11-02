import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// Offsets around sharp turns (MOD-26) and mirrored texts and symbols
/// (MOD-27).
void main() {
  int selfCrossings(List<Pt> o) {
    var n = 0;
    for (var i = 1; i < o.length; i++) {
      for (var j = i + 2; j < o.length; j++) {
        if (segmentIntersection(o[i - 1], o[i], o[j - 1], o[j]) != null) n++;
      }
    }
    return n;
  }

  group('offset (MOD-26)', () {
    // a guide turning back by 160°
    final v = [const Pt(0, 0), const Pt(100, 0), Pt(100 - 100 * math.cos(degToRad(20)), 100 * math.sin(degToRad(20)))];

    test('the outer side of a sharp turn is bevelled, not shot out', () {
      final o = offsetPolyline(v, -20);
      expect(o, hasLength(4), reason: 'two vertices for the corner');
      for (final q in o) {
        expect(math.min(q.distanceTo(v[1]), math.min(q.distanceTo(v[0]), q.distanceTo(v[2]))), lessThanOrEqualTo(20 + 1e-9));
      }
      // a gentle turn keeps its mitre (one vertex, the meeting of the offsets)
      final l = offsetPolyline(const [Pt(0, 0), Pt(10, 0), Pt(20, 5)], -1);
      expect(l, hasLength(3));
    });

    test('inside a turn the mitre stays within the segments; loops are cut', () {
      final small = offsetPolyline(v, 5);
      expect(small, hasLength(3));
      expect(small[1].x, inInclusiveRange(0, 100), reason: 'the meeting of the offset segments, inside');
      // too tight for the mitre (it would land 115 m away, beyond the guide):
      // every vertex stays at the offset distance from the guide
      final big = offsetPolyline(v, 20);
      for (final q in big) {
        final dist = math.min(distanceToSegment(q, v[0], v[1]), distanceToSegment(q, v[1], v[2]));
        expect(dist, lessThanOrEqualTo(20 + 1e-9), reason: '$q');
      }
      // an arc of radius 30 offset by 50 towards its centre
      final arc = [for (var i = 0; i <= 20; i++) Pt.polar(30, math.pi * i / 20)];
      expect(selfCrossings(offsetPolyline(arc, 50)), 0);
      // repeated vertices have no direction
      expect(offsetPolyline(const [Pt(0, 0), Pt(10, 0), Pt(10, 0), Pt(20, 0)], 1), const [Pt(0, 1), Pt(10, 1), Pt(20, 1)]);
    });

    test('a straight or gently curved line is offset as before', () {
      final line = [for (var i = 0; i <= 10; i++) Pt(i * 10.0, 3 * math.sin(i / 3))];
      final o = offsetPolyline(line, 2);
      expect(o, hasLength(line.length));
      for (var i = 0; i < line.length; i++) {
        expect(o[i].distanceTo(line[i]), inInclusiveRange(1.99, 2.2));
      }
    });
  });

  group('mirror (MOD-27)', () {
    final lr = Affine.mirror(const Pt(0, 0), const Pt(0, 1)); // left to right
    final ud = Affine.mirror(const Pt(0, 0), const Pt(1, 0)); // top to bottom

    test('a mirrored text keeps reading left to right over the mirrored box', () {
      final txt = TextEntity(id: 'e1', position: const Pt(10, 0), text: 'ZONA 1', height: 1);
      for (final m in [lr, ud]) {
        final t = txt.transformed(m);
        expect(t.rotationDeg, 0, reason: 'not upside down');
        final want = Bounds.ofPoints(txt.corners.map(m.apply));
        final got = t.bounds;
        expect(got.minX, closeTo(want.minX, 1e-9));
        expect(got.maxX, closeTo(want.maxX, 1e-9));
        expect(got.minY, closeTo(want.minY, 1e-9));
        expect(got.maxY, closeTo(want.maxY, 1e-9));
      }
      // a slanted text mirrored left to right reads the other slant
      final slant = TextEntity(id: 'e2', position: Pt.zero, text: 'AB', rotationDeg: 30).transformed(lr);
      expect(slant.rotationDeg, closeTo(-30, 1e-9));
    });

    test('the north arrow points north mirrored left to right and south mirrored top to bottom', () {
      final north = SymbolEntity(id: 'e3', position: const Pt(10, 0), kind: SymbolKind.northArrow);
      Pt tip(SymbolEntity s) => s.strokes()[0].last;
      expect(tip(north), const Pt(10, 2));
      final a = north.transformed(lr), b = north.transformed(ud);
      expect(tip(a).distanceTo(const Pt(-10, 2)), lessThan(1e-9));
      expect(tip(b).distanceTo(const Pt(10, -2)), lessThan(1e-9));
      expect(a.mirrored, isTrue);
      // twice is the original, and the flag is kept in the file
      final back = a.transformed(lr);
      expect(back.mirrored, isFalse);
      expect(tip(back).distanceTo(tip(north)), lessThan(1e-9));
      final read = Entity.fromJson(a.toJson()) as SymbolEntity;
      expect(read.mirrored, isTrue);
      expect(tip(read).distanceTo(tip(a)), lessThan(1e-9));
      // a rotation still turns it
      expect(tip(north.transformed(Affine.rotation(math.pi / 2, const Pt(10, 0)))).distanceTo(const Pt(8, 0)), lessThan(1e-9));
    });
  });
}
