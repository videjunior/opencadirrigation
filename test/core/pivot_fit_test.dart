import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/pivot_fit.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

List<Pt> _rect(double x0, double y0, double x1, double y1) => [Pt(x0, y0), Pt(x1, y0), Pt(x1, y1), Pt(x0, y1)];

/// Points of the wetted sector of [f] (on rings and rays) inside [field],
/// clear of [obstacles].
bool _sectorInside(PivotFit f, List<Pt> field, {List<List<Pt>> obstacles = const []}) {
  final r = f.irrigatedRadius;
  for (var i = 0; i <= 60; i++) {
    final a = degToRad(f.sectorStartDeg + f.sectorSweepDeg * i / 60);
    for (final k in const [0.25, 0.5, 0.75, 0.999]) {
      final p = f.center + Pt.polar(r * k, a);
      if (!pointInPolygon(p, field) && !pointOnPolygonBoundary(p, field, tol: 1e-3)) return false;
      for (final o in obstacles) {
        if (pointInPolygon(p, o) && !pointOnPolygonBoundary(p, o, tol: 1e-3)) return false;
      }
    }
  }
  return true;
}

void main() {
  group('machine length', () {
    test('spans and an overhang up to the length, fewest span lengths first', () {
      final c = snapPivotLength(400)!;
      expect(c.length, lessThanOrEqualTo(400 + 1e-9));
      expect(c.length, greaterThan(399));
      expect(c.spans.toSet().length, lessThanOrEqualTo(2));
      expect(defaultOverhangs, contains(c.overhang));
      // one length with uniform spans when it fits exactly
      final u = snapPivotLength(6 * 54.9, overhangs: const [0])!;
      expect(u.spans, List.filled(6, 54.9));
      expect(u.mainSpan, 54.9);
      expect(snapPivotLength(10), isNull);
      // the options are distinct and longest first
      final all = pivotLengthOptions(spans: const [40, 50], overhangs: const [0, 10], maxSpans: 4);
      for (var i = 1; i < all.length; i++) {
        expect(all[i].length, lessThan(all[i - 1].length));
      }
      expect(all.first.length, 4 * 50 + 10);
      expect(all.last.length, 40);
      expect(all.every((c) => c.count >= 1 && c.count <= 4), isTrue);
    });
  });

  group('full circle', () {
    test('the largest circle in a field, the machine snapped inside it', () {
      final f = fitFullCirclePivot(_rect(0, 0, 900, 650), PivotFitOptions(endThrowM: 15));
      expect(f.messages, isEmpty);
      expect(f.fullCircle, isTrue);
      expect(f.center.y, closeTo(325, 1));
      expect(f.center.x, inInclusiveRange(324, 576));
      expect(f.availableRadius, closeTo(325, 0.6));
      expect(f.irrigatedRadius, lessThanOrEqualTo(f.availableRadius + 1e-9));
      expect(f.irrigatedRadius, greaterThan(f.availableRadius - 12));
      expect(f.area, closeTo(math.pi * f.irrigatedRadius * f.irrigatedRadius, 1e-6));
      expect(f.coverage, closeTo(f.area / (900 * 650), 1e-9));
      expect(_sectorInside(f, _rect(0, 0, 900, 650)), isTrue);
    });

    test('obstacles and a power pole push the pivot aside', () {
      final house = _rect(400, 250, 500, 350);
      const pole = PointObstacle(Pt(200, 300), 10);
      final f = fitFullCirclePivot(_rect(0, 0, 900, 650), PivotFitOptions(obstacles: [house], pointObstacles: [pole]));
      expect(_sectorInside(f, _rect(0, 0, 900, 650), obstacles: [house]), isTrue);
      expect(f.center.distanceTo(pole.position), greaterThanOrEqualTo(f.irrigatedRadius + pole.radius - 1));
      expect(f.availableRadius, lessThan(325));
      // a field with no room for the shortest machine
      expect(fitFullCirclePivot(_rect(0, 0, 50, 50), PivotFitOptions()).messages, ['pivot_no_room']);
    });
  });

  group('part circle', () {
    test('an L-shaped field: a three-quarter circle round the inner corner beats the full circle', () {
      const field = [Pt(0, 0), Pt(800, 0), Pt(800, 300), Pt(300, 300), Pt(300, 800), Pt(0, 800)];
      final o = PivotFitOptions(endThrowM: 10);
      final sector = fitSectorPivot(field, o);
      final full = fitFullCirclePivot(field, o);
      expect(sector.messages, isEmpty);
      expect(sector.area, greaterThan(1.5 * full.area));
      expect(sector.sectorSweepDeg, greaterThan(180));
      expect(sector.sectorSweepDeg, lessThan(360));
      expect(_sectorInside(sector, field), isTrue);
      // the machine is a combination of spans and the sector its own area
      expect(sector.irrigatedRadius, closeTo(sector.machineLength + 10, 1e-9));
      expect(sector.area, closeTo(degToRad(sector.sectorSweepDeg) / 2 * math.pow(sector.irrigatedRadius, 2), 1e-6));
    });

    test('a rectangle: a sector from the edge waters more than the inscribed circle', () {
      final field = _rect(0, 0, 900, 650);
      final o = PivotFitOptions(endThrowM: 15);
      final sector = fitSectorPivot(field, o);
      expect(sector.area, greaterThanOrEqualTo(fitFullCirclePivot(field, o).area));
      expect(_sectorInside(sector, field), isTrue);
      // as a pivot of the project: the outline lies in the field
      final p = Project();
      final e = sector.toPivotEntity(p, zoneName: 'Pivot');
      expect(e.sectorDeg, closeTo(sector.sectorSweepDeg, 1e-9));
      expect(e.irrigatedRadius, closeTo(sector.irrigatedRadius, 1e-9));
      expect(e.zoneName, 'Pivot');
      for (final q in e.outline()) {
        expect(pointInPolygon(q, field) || pointOnPolygonBoundary(q, field, tol: 1e-3), isTrue, reason: '$q');
      }
    });

    test('a narrow sector is not worth a machine', () {
      final f = fitSectorPivot(const [Pt(0, 0), Pt(2000, 0), Pt(0, 60)], PivotFitOptions(minSweepDeg: 30));
      expect(f.spans == null || f.sectorSweepDeg >= 30 - 1e-9, isTrue);
      expect(fitSectorPivot(const [Pt(0, 0), Pt(1, 0)], PivotFitOptions()).messages, ['pivot_field_empty']);
    });

    test('fast enough for a dialog', () {
      final sw = Stopwatch()..start();
      fitSectorPivot(const [Pt(0, 0), Pt(1200, 100), Pt(1100, 900), Pt(300, 1000), Pt(-100, 500)], PivotFitOptions(endThrowM: 20, obstacles: [_rect(500, 400, 600, 500)]));
      expect(sw.elapsedMilliseconds, lessThan(3000));
    });
  });

  test('pivot entity of a full circle', () {
    final f = fitFullCirclePivot(_rect(0, 0, 900, 650), PivotFitOptions(endThrowM: 15));
    final e = f.toPivotEntity(Project());
    expect(e, isA<PivotEntity>());
    expect(e.sectorDeg, 360);
    expect(e.center, f.center);
    expect(e.radiusM, closeTo(f.machineLength, 1e-9));
    expect(e.endThrowM, 15);
  });
}
