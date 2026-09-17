import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// One instance of every entity type goes through JSON, clone, translation,
/// rotation, mirror, scale, grips and picking.
void main() {
  List<Entity> samples() => [
    LineEntity(id: 'e1', a: const Pt(0, 0), b: const Pt(10, 5)),
    PolylineEntity(id: 'e2', points: [const Pt(0, 0), const Pt(10, 0), const Pt(10, 10)], closed: true, name: 'Divisa'),
    CircleEntity(id: 'e3', center: const Pt(3, 4), radius: 2.5),
    ArcEntity(id: 'e4', center: const Pt(0, 0), radius: 5, startRad: 0, sweepRad: math.pi / 2),
    SplineEntity(id: 'e5', points: [const Pt(0, 0), const Pt(5, 5), const Pt(10, 0), const Pt(15, 5)]),
    HatchEntity(id: 'e6', points: [const Pt(0, 0), const Pt(10, 0), const Pt(10, 10)], angleDeg: 30, spacing: 0.5),
    HatchEntity(id: 'e6b', points: [const Pt(0, 0), const Pt(10, 0), const Pt(10, 10)], solid: true),
    SymbolEntity(id: 'e7', position: const Pt(1, 1), kind: SymbolKind.values.last, size: 3, rotationDeg: 15),
    TextEntity(id: 'e8', position: const Pt(2, 2), text: 'Olá', height: 1.5, rotationDeg: 30),
    DimensionEntity(id: 'e9', a: const Pt(0, 0), b: const Pt(10, 0), offset: 2),
    AngularDimensionEntity(id: 'e10', vertex: const Pt(0, 0), a: const Pt(10, 0), b: const Pt(0, 10), radius: 3),
    RadialDimensionEntity(id: 'e11', center: const Pt(0, 0), point: const Pt(4, 3)),
    LeaderEntity(id: 'e12', points: [const Pt(0, 0), const Pt(5, 5), const Pt(9, 5)], text: 'Nota', height: 1),
    ImageEntity(id: 'e13', origin: const Pt(0, 0), width: 20, height: 10, rotationDeg: 10, opacity: 0.5, data: Uint8List.fromList([1, 2, 3, 4]), source: 'foto.png'),
    ContourEntity(id: 'e14', points: [const Pt(0, 0), const Pt(10, 1), const Pt(20, 0)], elevation: 101.5),
    SpotHeightEntity(id: 'e15', position: const Pt(3, 3), elevation: 99.2),
    PipeEntity(id: 'e16', points: [const Pt(0, 0), const Pt(50, 0)], scope: HydraulicScope.mainline, pipeSpecId: 'pvc50'),
    TapeEntity(id: 'e17', points: [const Pt(0, 0), const Pt(0, 40)], tapeSpecId: 't16', inletHeadM: 8),
    OutletEntity(id: 'e18', position: const Pt(1, 2), outletSpecId: 'o1', headM: 15, arcDeg: 180, orientationDeg: 45),
    ControlValveEntity(id: 'e19', position: const Pt(5, 5), valveSpecId: 'v1', zoneName: 'Zona X'),
    WaterSupplyEntity(id: 'e20', position: const Pt(0, 0), designHeadM: 30, designFlow: 0.01),
    PumpEntity(id: 'e21', position: const Pt(1, 0), pumpSpecId: 'p1', speedRatio: 0.9),
    MiscHydraulicEntity(id: 'e22', position: const Pt(2, 0), valveSpecId: 'filter', settingM: 5),
    JunctionEntity(id: 'e23', position: const Pt(3, 0), fixedElevation: 100),
  ];

  test('every sample survives a JSON round trip through the project', () {
    final p = Project();
    for (final e in samples()) {
      p.entities.add(e);
    }
    final back = Project.fromJsonString(p.toJsonString());
    expect(back.entities.length, p.entities.length);
    for (var i = 0; i < p.entities.length; i++) {
      final a = p.entities[i], b = back.entities[i];
      expect(b.runtimeType, a.runtimeType, reason: a.id);
      expect(b.id, a.id);
      expect(b.layer, a.layer);
      expect(b.name, a.name);
      expect(b.bounds.minX, closeTo(a.bounds.minX, 1e-9), reason: a.id);
      expect(b.bounds.maxY, closeTo(a.bounds.maxY, 1e-9), reason: a.id);
    }
    final s = back.entities.whereType<SymbolEntity>().first;
    expect(s.kind, SymbolKind.values.last);
    expect(back.entities.whereType<ImageEntity>().first.data, [1, 2, 3, 4]);
    expect(back.entities.whereType<OutletEntity>().first.arcDeg, 180);
    expect(back.entities.whereType<JunctionEntity>().first.fixedElevation, 100);
    final single = Entity.fromJson(samples().last.toJson());
    expect(single, isA<JunctionEntity>());
  });

  test('clone, translate, rotate, mirror and scale keep the geometry consistent', () {
    for (final e in samples()) {
      final c = e.clone(newId: 'copy');
      expect(c.id, 'copy');
      expect(c.runtimeType, e.runtimeType);
      final t = e.translated(const Pt(5, -3));
      expect(t.bounds.minX, closeTo(e.bounds.minX + 5, 1e-9), reason: e.id);
      expect(t.bounds.minY, closeTo(e.bounds.minY - 3, 1e-9), reason: e.id);
      // geometric grips follow the transform exactly (bounds of texts and
      // symbols depend on the rotation, so grips are the robust check)
      bool sameSet(List<Pt> a, List<Pt> b) => a.length == b.length && a.every((p) => b.any((q) => p.distanceTo(q) < 1e-6));
      for (final t in [Affine.rotation(math.pi / 2, const Pt(0, 0)), Affine.mirror(const Pt(0, 0), const Pt(0, 1)), Affine.scaling(2, const Pt(0, 0))]) {
        final out = e.transformed(t);
        expect(out.runtimeType, e.runtimeType);
        expect(sameSet(out.grips, e.grips.map(t.apply).toList()), isTrue, reason: '${e.id} ${t.isMirror ? 'mirror' : ''}');
      }
      expect(e.transformed(Affine.scaling(2, const Pt(0, 0))).bounds.width, closeTo(e.bounds.width * 2, 1e-6), reason: e.id);
      // grips can be read and written back without changing the type
      final grips = e.grips;
      expect(grips, isNotEmpty, reason: e.id);
      for (var i = 0; i < grips.length; i++) {
        e.setGrip(i, grips[i] + const Pt(0.01, 0.01));
      }
      expect(e.grips.length, grips.length);
      expect(e.distanceTo(e.grips.first), lessThan(50), reason: e.id);
      expect(e.distanceTo(const Pt(1e4, 1e4)), greaterThan(1e3), reason: e.id);
    }
  });

  test('linear helpers, polylines and areas', () {
    final poly = PolylineEntity(id: 'p', points: [const Pt(0, 0), const Pt(10, 0), const Pt(10, 10), const Pt(0, 10)], closed: true);
    expect(poly.length, closeTo(40, 1e-9));
    expect(poly.area, closeTo(100, 1e-9));
    poly.insertVertex(1, const Pt(5, -1));
    expect(poly.points.length, 5);
    poly.removeVertex(1);
    expect(poly.points.length, 4);
    final pipe = PipeEntity(id: 'q', points: const [Pt(0, 0), Pt(30, 40)], scope: HydraulicScope.zone, pipeSpecId: 'x');
    expect(pipe.length, closeTo(50, 1e-9));
    expect(pipe.isLinearHydraulic, isTrue);
    expect(pipe.linearPoints, isNotNull);
    expect(poly.isClosedShape, isTrue);
    final arc = ArcEntity(id: 'a', center: const Pt(0, 0), radius: 10, startRad: 0, sweepRad: math.pi);
    expect(arc.length, closeTo(math.pi * 10, 1e-6));
    final area = AreaEntity(id: 'ar', points: const [Pt(0, 0), Pt(100, 0), Pt(100, 100), Pt(0, 100)], etoMmDay: 5, kc: 0.8);
    expect(area.area, closeTo(10000, 1e-6));
    expect(area.etcMmDay, closeTo(4, 1e-9));
    expect(area.effectiveNetDepthMmPerDay, greaterThan(0));
    final ang = AngularDimensionEntity(id: 'g', vertex: const Pt(0, 0), a: const Pt(1, 0), b: const Pt(0, 1));
    expect(ang.angleDeg, closeTo(90, 1e-9));
    expect(ang.arcPoints().length, greaterThan(2));
  });
}
