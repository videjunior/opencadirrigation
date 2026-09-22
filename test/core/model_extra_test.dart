import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/pivot.dart' show PivotKind;
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/catalog_packs.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/split.dart';
import 'package:opencadirrigation/core/model/terrain.dart';
import 'package:opencadirrigation/core/model/tin.dart';
import 'package:opencadirrigation/core/units.dart';

/// Model helpers not covered elsewhere: points and transforms, terrain and
/// TIN edge cases, catalogue and project utilities, entity behaviour and the
/// split / extend / offset operations on every entity type.
void main() {
  group('geometry', () {
    test('points rotate, serialise and hash by value', () {
      final r = const Pt(1, 0).rotate(math.pi / 2);
      expect(r.x, closeTo(0, 1e-12));
      expect(r.y, closeTo(1, 1e-12));
      expect(Pt.fromJson(const Pt(1.5, -2).toJson()), const Pt(1.5, -2));
      expect(Pt.fromJson({'x': 3, 'y': 4}), const Pt(3, 4), reason: 'integers in JSON are accepted');
      final a = Pt(1, 2 + 0.0 * math.pi), b = Pt(1.0, 2.0);
      expect(identical(a, b), isFalse);
      expect({a, b, const Pt(2, 1)}.length, 2, reason: 'equal points hash alike');
      expect(const Pt(1, 2).hashCode, const Pt(1, 2).hashCode);
    });

    test('centroid of degenerate polygons is the mean of the vertices', () {
      expect(polygonCentroid(const []), Pt.zero);
      final line = polygonCentroid([const Pt(0, 0), const Pt(4, 0), const Pt(8, 0)]);
      expect(line.x, closeTo(4, 1e-12));
      expect(line.y, closeTo(0, 1e-12));
      final sq = polygonCentroid([const Pt(0, 0), const Pt(4, 0), const Pt(4, 2), const Pt(0, 2)]);
      expect(sq.x, closeTo(2, 1e-12));
      expect(sq.y, closeTo(1, 1e-12));
    });

    test('points along a polyline are clamped to its ends', () {
      final pts = [const Pt(0, 0), const Pt(10, 0), const Pt(10, 10)];
      expect(pointAlongPolyline(pts, 50), const Pt(10, 10));
      expect(pointAlongPolyline(pts, -5), const Pt(0, 0));
      expect(pointAlongPolyline([const Pt(3, 3)], 5), const Pt(3, 3));
      expect(pointAlongPolyline(const [], 5), Pt.zero);
    });

    test('an open Catmull-Rom curve bends in its first and last spans too', () {
      final pts = [const Pt(0, 0), const Pt(5, 5), const Pt(10, 0)];
      final c = catmullRom(pts, segments: 8);
      expect(c.length, 17);
      expect(c[0], pts[0]);
      expect(c[8].distanceTo(pts[1]), lessThan(1e-9), reason: 'the curve passes through the fit points');
      expect(c[16], pts[2]);
      // the middle of each end span leaves the straight chord…
      expect(distanceToSegment(c[4], pts[0], pts[1]), greaterThan(0.1));
      expect(distanceToSegment(c[12], pts[1], pts[2]), greaterThan(0.1));
      // …symmetrically, bulging away from the opposite end
      expect(c[12].x, closeTo(10 - c[4].x, 1e-9));
      expect(c[12].y, closeTo(c[4].y, 1e-9));
      expect(c[4].y, greaterThan(c[4].x));
      expect(polylineLength(c), greaterThan(polylineLength(pts)));
      expect(catmullRom([Pt.zero, const Pt(1, 1)]), [Pt.zero, const Pt(1, 1)]);
      expect(catmullRom([const Pt(0, 0), const Pt(1, 0), const Pt(2, 0)], segments: 4).every((p) => p.y.abs() < 1e-12), isTrue, reason: 'collinear points stay straight');
      final closed = catmullRom([const Pt(0, 0), const Pt(10, 0), const Pt(10, 10), const Pt(0, 10)], closed: true, segments: 4);
      expect(closed.length, 17);
      expect(closed.last, closed.first);
    });

    test('identity transforms and closed polyline intersections', () {
      expect(Affine.identity.isIdentity, isTrue);
      expect(Affine.translation(const Pt(1, 0)).isIdentity, isFalse);
      expect(Affine.rotation(0).isIdentity, isTrue);
      // the closing edge of a closed polyline counts only when asked
      final square = [const Pt(0, 0), const Pt(10, 0), const Pt(10, 10), const Pt(0, 10)];
      final cut = [const Pt(-5, 5), const Pt(15, 5)];
      expect(polylineIntersections(square, cut).length, 1, reason: 'open: the left side is missing');
      expect(polylineIntersections(square, cut, closedA: true).length, 2);
    });
  });

  group('units', () {
    test('copyWith keeps the other units; roundTo rounds half away', () {
      final u = Units.metric.copyWith(flow: FlowUnit.m3h);
      expect(u.flow, FlowUnit.m3h);
      expect(u.length, LengthUnit.m);
      expect(u.pressure, PressureUnit.mH2O);
      expect(u.diameter, DiameterUnit.mm);
      expect(Units.us.copyWith().toJson(), Units.us.toJson());
      expect(roundTo(1.23456, 2), 1.23);
      expect(roundTo(1.235, 1), 1.2);
      expect(roundTo(-2.5, 0), -3);
      expect(roundTo(1234.5, -2), 1200);
    });
  });

  group('terrain', () {
    test('samples in the constructor, addAll, a one-point contour and clear', () {
      final t = Terrain(samples: const [TerrainSample(Pt(0, 0), 100), TerrainSample(Pt(10, 0), 110)], densify: 1);
      expect(t.sampleCount, 2);
      expect(t.samples.map((s) => s.z), [100, 110]);
      expect(() => t.samples.add(const TerrainSample(Pt.zero, 1)), throwsUnsupportedError, reason: 'read-only view');
      t.addAll(const [TerrainSample(Pt(0, 10), 105)]);
      t.addContour([const Pt(10, 10)], 115);
      t.addContour(const [], 999);
      expect(t.sampleCount, 4);
      expect(t.elevationAt(const Pt(10, 10)), closeTo(115, 1e-6));
      expect(t.elevationAt(const Pt(5, 5)), inInclusiveRange(100, 115));
      t.clear();
      expect(t.isEmpty, isTrue);
      expect(t.slopeAt(const Pt(1, 1)), 0);
    });

    test('slope outside the TIN comes from finite differences of the IDW surface', () {
      final t = Terrain(densify: 2);
      t.addContour([const Pt(0, 0), const Pt(100, 0)], 100);
      t.addContour([const Pt(0, 40), const Pt(100, 40)], 104);
      // far outside the hull: IDW is almost flat there, but finite
      final s = t.slopeAt(const Pt(50, 500));
      expect(s.isFinite, isTrue);
      expect(s, lessThan(0.1));
      // the IDW method always uses finite differences; on a surveyed grid of a
      // 10 % plane the slope comes out close to 0.1 (between two long parallel
      // contours the 8 nearest samples all sit on one line, so IDW terraces:
      // that is why the TIN is the default)
      final idw = Terrain(densify: 2, method: TerrainMethod.idw);
      for (var i = 0; i <= 20; i++) {
        for (var j = 0; j <= 20; j++) {
          idw.addSpot(Pt(i * 5.0, j * 5.0), 100 + 0.1 * j * 5.0);
        }
      }
      expect(idw.slopeAt(const Pt(52, 48)), inInclusiveRange(0.05, 0.15));
    });

    test('TIN: duplicates merge (last height wins), vertices and empty inputs', () {
      final tin = Tin.build([(0, 0, 1), (10, 0, 2), (0, 10, 3), (0, 0, 5), (double.nan, 1, 1)]);
      expect(tin.pointCount, 3);
      expect(tin.isEmpty, isFalse);
      expect(tin.vertex(0), const Pt(0, 0));
      expect(tin.elevationAt(const Pt(0, 0)), closeTo(5, 1e-9));
      expect(Tin.build([(0, 0, 1), (1, 1, 2)]).isEmpty, isTrue, reason: 'two points make no triangle');
      expect(Tin.build(const []).pointCount, 0);
    });
  });

  group('catalog', () {
    test('tape SDR, pump refit, deep copy, replace-merge and new ids', () {
      final c = Catalog.defaultCatalog();
      final tape = c.tapes.first;
      expect(tape.nominalSdr, closeTo(tape.emitter.flow(tape.defaultInletHeadM) * 100 / tape.emitterSpacingM, 1e-15));
      expect(tape.nominalSdr / m3sPerLph, greaterThan(100), reason: 'L/h per 100 m of tape');
      final pump = c.pumps.first;
      pump.points = [(0.0, 30.0), (0.01, 25.0), (0.02, 10.0)];
      pump.refit();
      expect(pump.curve.head(0.01), closeTo(25, 1e-6));
      final copy = c.copy();
      copy.pipes.first.costPerM = 999;
      copy.pipes.removeLast();
      expect(c.pipes.first.costPerM, isNot(999));
      expect(copy.pipes.length, c.pipes.length - 1);
      // merge adds the missing ids; with replace it overwrites the others too
      final other = Catalog(pipes: [PipeSpec(id: c.pipes.first.id, name: 'replaced', nominalMm: 50, innerDiameterMm: 46), PipeSpec(id: 'brand_new', name: 'new', nominalMm: 50, innerDiameterMm: 46)]);
      expect(c.merge(other), 1);
      expect(c.pipes.first.name, isNot('replaced'));
      expect(c.merge(other, replace: true), 2);
      expect(c.pipes.first.name, 'replaced');
      expect(c.newId('brand_new'), 'brand_new1');
      c.pipes.add(PipeSpec(id: 'x1', name: 'x', nominalMm: 1, innerDiameterMm: 1));
      c.pipes.add(PipeSpec(id: 'x2', name: 'x', nominalMm: 1, innerDiameterMm: 1));
      expect(c.newId('x'), 'x3');
    });

    test('packs merge fittings too, skipping the ids already there', () {
      final target = Catalog(fittings: [FittingSpec(id: 'f1', name: 'a', kind: FittingKind.tee, sizeMm: 50)]);
      final pack = Catalog(fittings: [FittingSpec(id: 'f1', name: 'dup', kind: FittingKind.tee, sizeMm: 50), FittingSpec(id: 'f2', name: 'b', kind: FittingKind.elbow90, sizeMm: 50)]);
      expect(mergeCatalogPack(target, pack), 1);
      expect(target.fittings.map((f) => f.id), ['f1', 'f2']);
      expect(target.fittings.first.name, 'a');
    });
  });

  group('project', () {
    test('ofType, deep copy, defaults for missing sections and unique zone names', () {
      final p = Project();
      p.entities.addAll([
        ControlValveEntity(id: p.newId(), position: Pt.zero, zoneName: 'Zona 1'),
        ControlValveEntity(id: p.newId(), position: const Pt(5, 0), zoneName: 'Zona 2'),
        LineEntity(id: p.newId(), a: Pt.zero, b: const Pt(1, 1)),
      ]);
      expect(p.ofType<ControlValveEntity>().length, 2);
      expect(p.ofType<LineEntity>().single.id, 'e3');
      expect(p.uniqueZoneName('Zona'), 'Zona 3');
      final copy = p.copy();
      (copy.entities.first as ControlValveEntity).zoneName = 'mudou';
      expect((p.entities.first as ControlValveEntity).zoneName, 'Zona 1');
      expect(copy.toJsonString(), isNot(p.toJsonString()));
      expect(DesignParameters.fromJson(null).toJson(), DesignParameters().toJson());
      expect(ProjectMeta.fromJson(null).name, ProjectMeta().name);
      final bare = Project.fromJson({'format': Project.formatName});
      expect(bare.layers.map((l) => l.name), containsAll([Layers.drawing, Layers.mainlinePipes]));
      expect(bare.catalog.pipes, isNotEmpty);
      expect(bare.entities, isEmpty);
      expect(() => Project.fromJson({'format': 'other'}), throwsFormatException);
    });
  });

  group('entities', () {
    test('a spline is longer than its chord and every symbol kind has strokes', () {
      final s = SplineEntity(id: 's', points: [const Pt(0, 0), const Pt(5, 5), const Pt(10, 0)]);
      expect(s.length, greaterThan(polylineLength(s.points) * 0.99));
      expect(s.length, greaterThan(10));
      for (final k in SymbolKind.values) {
        final strokes = SymbolEntity(id: 'y', position: const Pt(10, 10), kind: k, size: 2).strokes();
        expect(strokes, isNotEmpty, reason: k.name);
        for (final st in strokes) {
          expect(st.length, greaterThanOrEqualTo(2), reason: k.name);
          for (final p in st) {
            expect(p.distanceTo(const Pt(10, 10)), lessThanOrEqualTo(2 * math.sqrt2 + 1e-9), reason: '${k.name} stays within its size');
          }
        }
      }
    });

    test('a rotated text has a rotated box for bounds and picking', () {
      final t = TextEntity(id: 't', position: Pt.zero, text: 'abcd', height: 1, rotationDeg: 90);
      final b = t.bounds;
      expect(b.minX, closeTo(-1, 1e-9));
      expect(b.maxX, closeTo(0, 1e-9));
      expect(b.minY, closeTo(0, 1e-9));
      expect(b.maxY, closeTo(2.4, 1e-9), reason: '4 characters × 0.6 × height, upwards');
      expect(t.distanceTo(const Pt(-0.5, 1.2)), 0);
      expect(t.distanceTo(const Pt(1.2, 0.5)), greaterThan(1), reason: 'where the unrotated box would be');
      final flat = TextEntity(id: 'f', position: const Pt(2, 3), text: 'ab', height: 2);
      expect((flat.bounds.minX, flat.bounds.minY, flat.bounds.maxX, flat.bounds.maxY), (2, 3, 4.4, 5));
      final rt = flat.transformed(Affine.rotation(math.pi, const Pt(2, 3)));
      expect(rt.bounds.center.distanceTo(Pt.lerp(const Pt(2, 3), const Pt(-0.4, 1), 0.5)), lessThan(1e-9), reason: 'turned half a turn about its insertion point');
    });

    test('angular dimension text sits on the bisector just outside the arc', () {
      final d = AngularDimensionEntity(id: 'a', vertex: Pt.zero, a: const Pt(10, 0), b: const Pt(0, 10), radius: 4);
      final tp = d.textPoint;
      expect(tp.distanceTo(Pt.zero), closeTo(4 * 1.15, 1e-9));
      expect(tp.angle, closeTo(math.pi / 4, 1e-9));
    });

    test('pivot: distance to the machine, grips and translation; linear outline', () {
      final pv = PivotEntity(id: 'p', center: Pt.zero, radiusM: 100, endThrowM: 0);
      expect(pv.distanceTo(const Pt(50, 0)), closeTo(0, 1e-9), reason: 'on the span');
      expect(pv.distanceTo(const Pt(0, 100)), closeTo(0, 1e-9), reason: 'on the circle');
      expect(pv.distanceTo(const Pt(0, 60)), closeTo(40, 1e-9));
      pv.setGrip(1, const Pt(0, 150));
      expect(pv.radiusM, closeTo(150, 1e-9));
      expect(pv.angleDeg, closeTo(90, 1e-9));
      pv.setGrip(1, pv.center);
      expect(pv.radiusM, closeTo(150, 1e-9), reason: 'a zero-length span is ignored');
      pv.setGrip(0, const Pt(10, 10));
      expect(pv.center, const Pt(10, 10));
      final moved = pv.translated(const Pt(5, -5));
      expect(moved.center, const Pt(15, 5));
      expect(moved.radiusM, pv.radiusM);
      expect(identical(moved, pv), isFalse);
      final lin = PivotEntity(id: 'l', center: Pt.zero, radiusM: 100, endThrowM: 0, kind: PivotKind.linear, travelM: 300);
      expect(lin.outline().length, 4);
      expect(lin.distanceTo(const Pt(50, 300)), closeTo(0, 1e-9), reason: 'on the far side of the rectangle');
      expect(lin.distanceTo(const Pt(50, 150)), closeTo(50, 1e-9));
      expect(lin.hydraulicScope, HydraulicScope.mainline);
      expect(JunctionEntity(id: 'j', position: Pt.zero, scope: HydraulicScope.mainline).hydraulicScope, HydraulicScope.mainline);
      expect(JunctionEntity(id: 'j', position: Pt.zero).hydraulicScope, HydraulicScope.zone);
    });

    test('area: inside is at distance zero; the closing edge counts; transforms keep the crop data', () {
      final a = AreaEntity(id: 'a', points: [const Pt(0, 0), const Pt(10, 0), const Pt(10, 10), const Pt(0, 10)], kc: 0.9, etoMmDay: 6);
      expect(a.distanceTo(const Pt(5, 5)), 0);
      expect(a.distanceTo(const Pt(-3, 5)), closeTo(3, 1e-9), reason: 'the edge from the last vertex back to the first');
      final r = a.transformed(Affine.rotation(math.pi / 2));
      expect(r.area, closeTo(100, 1e-9));
      expect(r.kc, 0.9);
      expect(r.etcMmDay, closeTo(5.4, 1e-12));
      expect(r.points[1].x, closeTo(0, 1e-9));
      expect(r.points[1].y, closeTo(10, 1e-9));
    });
  });

  group('split, extend and offset every entity type', () {
    var seq = 0;
    String id() => 'n${seq++}';

    test('polylines, contours, tapes, splines and leaders split at a station', () {
      final pts = [const Pt(0, 0), const Pt(10, 0), const Pt(20, 0)];
      final cases = <Entity>[
        PolylineEntity(id: 'pl', name: 'Divisa', points: List.of(pts)),
        ContourEntity(id: 'ct', points: List.of(pts), elevation: 101),
        TapeEntity(id: 'tp', points: List.of(pts), tapeSpecId: 't', inletHeadM: 9, flushingFlow: 1e-4),
        SplineEntity(id: 'sp', points: List.of(pts)),
        LeaderEntity(id: 'ld', points: List.of(pts), text: 'nota', height: 2),
      ];
      for (final e in cases) {
        final pieces = splitLinearEntity(e, [5], id);
        expect(pieces.length, 2, reason: e.type.name);
        expect(pieces.first.id, e.id);
        expect(pieces.every((p) => p.runtimeType == e.runtimeType), isTrue, reason: e.type.name);
        expect(polylineLength(pieces.first.linearPoints!) + polylineLength(pieces.last.linearPoints!), closeTo(20, 1e-9));
      }
      final pl = splitLinearEntity(cases[0], [5], id);
      expect(pl.last.name, 'Divisa (2)');
      expect((splitLinearEntity(cases[1], [5], id).last as ContourEntity).elevation, 101);
      final tapes = splitLinearEntity(cases[2], [5], id).cast<TapeEntity>();
      expect(tapes.first.flushingFlow, 0, reason: 'only the last piece flushes');
      expect(tapes.last.flushingFlow, 1e-4);
      expect(tapes.last.inletHeadM, 9);
      expect((splitLinearEntity(cases[4], [5], id).last as LeaderEntity).text, 'nota');
      // entities that are not linear, or cuts at the ends, are left alone
      final circle = CircleEntity(id: 'c', center: Pt.zero, radius: 3);
      expect(splitLinearEntity(circle, [1], id), [circle]);
      final arc = ArcEntity(id: 'a', center: Pt.zero, radius: 5, startRad: 0, sweepRad: math.pi);
      expect(splitLinearEntity(arc, [3], id), [arc], reason: 'arcs are not cut into pieces');
      expect(splitLinearEntity(cases[0], [0, 20], id), [cases[0]]);
    });

    test('extend moves the start of a line and the end vertex of a polyline', () {
      final wall = [[const Pt(-10, -5), const Pt(-10, 5)]];
      final l = LineEntity(id: 'l', a: const Pt(0, 0), b: const Pt(5, 0));
      expect(extendLinearEntity(l, const Pt(0.5, 0), wall), isTrue);
      expect(l.a.x, closeTo(-10, 1e-9));
      expect(l.b.x, closeTo(5, 1e-9));
      final p = PolylineEntity(id: 'p', points: [const Pt(0, 0), const Pt(5, 0), const Pt(5, 5)]);
      expect(extendLinearEntity(p, const Pt(5, 4), [[const Pt(0, 12), const Pt(10, 12)]]), isTrue);
      expect(p.points.last.y, closeTo(12, 1e-9));
      expect(p.points.length, 3);
      // nothing ahead: unchanged
      expect(extendLinearEntity(p, const Pt(5, 4), [[const Pt(0, -12), const Pt(10, -12)]]), isFalse);
      expect(extendLinearEntity(CircleEntity(id: 'c', center: Pt.zero, radius: 1), Pt.zero, wall), isFalse);
    });

    test('offset of arcs, contours, pipes, laterals, tapes, splines, closed polylines and areas', () {
      final arc = offsetEntity(ArcEntity(id: 'a', center: Pt.zero, radius: 5, startRad: 0, sweepRad: 1), 2, 'o') as ArcEntity;
      expect(arc.radius, 7);
      expect(arc.sweepRad, 1);
      expect(offsetEntity(ArcEntity(id: 'a', center: Pt.zero, radius: 1, startRad: 0, sweepRad: 1), -2, 'o'), isNull, reason: 'a negative radius is refused');
      final line = [const Pt(0, 0), const Pt(10, 0)];
      final contour = offsetEntity(ContourEntity(id: 'c', points: List.of(line), elevation: 7), 1, 'o') as ContourEntity;
      expect(contour.elevation, 7);
      expect(contour.points.first.y, closeTo(1, 1e-9));
      final pipe = offsetEntity(PipeEntity(id: 'p', points: List.of(line), scope: HydraulicScope.mainline, pipeSpecId: 'pvc50', depth: 0.6), -1, 'o') as PipeEntity;
      expect(pipe.points.first.y, closeTo(-1, 1e-9));
      expect(pipe.scope, HydraulicScope.mainline);
      expect(pipe.pipeSpecId, 'pvc50');
      expect(pipe.depth, 0.6);
      final lat = offsetEntity(SpraylineEntity(id: 's', points: List.of(line), outletSpecId: 'micro', spacing: 2), 3, 'o') as SpraylineEntity;
      expect(lat.id, 'o');
      expect(lat.points.last.y, closeTo(3, 1e-9));
      expect(lat.spacing, 2);
      final tape = offsetEntity(TapeEntity(id: 't', points: List.of(line), tapeSpecId: 'tp'), 0.5, 'o') as TapeEntity;
      expect(tape.tapeSpecId, 'tp');
      expect(tape.points.first.y, closeTo(0.5, 1e-9));
      final spline = offsetEntity(SplineEntity(id: 'sp', points: List.of(line), closed: false), 1, 'o') as SplineEntity;
      expect(spline.points.first.y, closeTo(1, 1e-9));
      // closed shapes drawn counter-clockwise: a positive offset (to the left) goes inside
      final square = [const Pt(0, 0), const Pt(10, 0), const Pt(10, 10), const Pt(0, 10)];
      final inner = offsetEntity(PolylineEntity(id: 'q', points: List.of(square), closed: true), 1, 'o') as PolylineEntity;
      expect(inner.closed, isTrue);
      expect(inner.points.length, 4);
      for (final (p, want) in [(inner.points[0], const Pt(1, 1)), (inner.points[1], const Pt(9, 1)), (inner.points[2], const Pt(9, 9)), (inner.points[3], const Pt(1, 9))]) {
        expect(p.distanceTo(want), lessThan(1e-9), reason: '$p');
      }
      final area = offsetEntity(AreaEntity(id: 'ar', points: List.of(square), kc: 0.7), -1, 'o') as AreaEntity;
      expect(area.area, closeTo(144, 1e-9), reason: 'outward by 1 m: 12 × 12');
      expect(area.kc, 0.7);
      expect(offsetEntity(TextEntity(id: 't', position: Pt.zero, text: 'x'), 1, 'o'), isNull);
    });
  });
}
