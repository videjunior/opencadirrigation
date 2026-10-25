import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/io/dxf.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/terrain.dart';
import 'package:opencadirrigation/core/model/tin.dart';

/// Breaklines: the triangulation keeps their segments as edges, so a valley
/// surveyed on its slopes folds along the channel instead of being bridged
/// across it.
void main() {
  // a V valley along y = 0: z = 100 + 0.1·|y|, surveyed on the slopes only
  List<(double, double, double)> slopes() => [
    for (var x = 0.0; x <= 100; x += 20)
      for (final y in [-20.0, -10.0, 10.0, 20.0]) (x, y, 100 + 0.1 * y.abs()),
  ];

  bool crosses(Pt a, Pt b, Pt c, Pt d) {
    double o(Pt p, Pt q, Pt r) => (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x);
    final o1 = o(a, b, c), o2 = o(a, b, d), o3 = o(c, d, a), o4 = o(c, d, b);
    return o1 * o2 < -1e-9 && o3 * o4 < -1e-9;
  }

  test('without the breakline the valley is bridged; with it the surface folds along the channel', () {
    final plain = Tin.build(slopes());
    expect(plain.elevationAt(const Pt(50, 0))!, greaterThan(100.9), reason: 'interpolated across the channel');
    final tin = Tin.build(slopes(), breaklines: [
      [(0, 0, 100), (50, 0, 100), (100, 0, 100)],
    ]);
    expect(tin.elevationAt(const Pt(50, 0))!, closeTo(100, 1e-9));
    expect(tin.elevationAt(const Pt(30, 0))!, closeTo(100, 1e-9));
    expect(tin.elevationAt(const Pt(30, 5))!, closeTo(100.5, 1e-9));
    expect(tin.elevationAt(const Pt(70, -7.5))!, closeTo(100.75, 1e-9));
    // no edge crosses the channel
    for (final t in tin.triangles) {
      for (final (u, v) in [(t.a, t.b), (t.b, t.c), (t.c, t.a)]) {
        expect(crosses(tin.vertex(u), tin.vertex(v), const Pt(0, 0), const Pt(100, 0)), isFalse);
      }
    }
  });

  test('a long diagonal breakline is forced through a dense triangulation', () {
    final pts = [
      for (var x = 0.0; x <= 100; x += 7)
        for (var y = 0.0; y <= 100; y += 7) (x + (y % 3) * 0.37, y + (x % 5) * 0.21, 50.0),
    ];
    final tin = Tin.build(pts, breaklines: [
      [(1, 2, 60), (99, 97, 60)],
    ]);
    const a = Pt(1, 2), b = Pt(99, 97);
    for (final t in tin.triangles) {
      for (final (u, v) in [(t.a, t.b), (t.b, t.c), (t.c, t.a)]) {
        expect(crosses(tin.vertex(u), tin.vertex(v), a, b), isFalse);
      }
    }
    expect(tin.elevationAt(Pt.lerp(a, b, 0.5))!, closeTo(60, 1e-9));
  });

  test('vertices without an elevation take it from the other data; IDW sees the breakline too', () {
    final t = Terrain(densify: 10);
    for (final (x, y, z) in slopes()) {
      t.addSpot(Pt(x, y), z);
    }
    t.addBreakline(const [Pt(0, 0), Pt(100, 0)], const [100, double.nan]);
    expect(t.elevationAt(const Pt(0, 0)), closeTo(100, 1e-9));
    final end = t.elevationAt(const Pt(100, 0));
    expect(end, greaterThan(100.5), reason: 'interpolated from the slopes around (100, 0)');
    expect(t.breaklineCount, 1);
    final idw = Terrain(densify: 10, method: TerrainMethod.idw)..addBreakline(const [Pt(0, 0), Pt(10, 0)], const [5, 5]);
    expect(idw.isEmpty, isFalse);
    expect(idw.elevationAt(const Pt(5, 0.1)), closeTo(5, 1e-9));
  });

  test('the entity keeps its elevations through JSON, copies and transforms; the project terrain uses it', () {
    final b = BreaklineEntity(id: 'b1', points: const [Pt(0, 0), Pt(50, 0), Pt(100, 0)], elevations: const [100, double.nan, 100]);
    final back = Entity.fromJson(jsonDecode(jsonEncode(b.toJson())) as Map<String, dynamic>) as BreaklineEntity;
    expect(back.layer, Layers.breaklines);
    expect(back.elevationOf(0), 100);
    expect(back.elevationOf(1).isNaN, isTrue);
    expect(back.elevationOf(5).isNaN, isTrue);
    final copy = b.clone(newId: 'b2')..elevations[0] = 90;
    expect(b.elevationOf(0), 100);
    expect(copy.translated(const Pt(1, 1)).points.first, const Pt(1, 1));
    final p = Project();
    for (final (x, y, z) in slopes()) {
      p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt(x, y), elevation: z));
    }
    p.entities.add(b);
    final terrain = p.buildTerrain();
    expect(terrain.elevationAt(const Pt(0, 0)), closeTo(100, 1e-9));
    // the middle vertex has no elevation: it comes from the slopes around it
    expect(terrain.elevationAt(const Pt(25, 0)), inExclusiveRange(100, 101.5));
  });

  test('DXF round trip: a breakline layer comes back as breaklines', () {
    final c = ProjectController()..newProject();
    c.addEntity(BreaklineEntity(id: c.project.newId(), points: const [Pt(0, 0), Pt(30, 10)], elevations: const [12, 13]));
    c.addEntity(CommentEntity(id: c.project.newId(), position: const Pt(5, 5), text: 'conferir cota', author: 'MJ'));
    c.addEntity(RevisionCloudEntity(id: c.project.newId(), points: const [Pt(0, 0), Pt(10, 0), Pt(10, 10), Pt(0, 10)], revision: 'B', description: 'novo setor'));
    final dxf = c.exporter().dxf();
    expect(dxf, contains('BREAKLINES'));
    expect(dxf, contains('conferir cota'));
    expect(dxf, contains('novo setor'));
    final d = ProjectController()..newProject();
    d.importDrawing(DxfReader.parse(dxf));
    final bl = d.project.entities.whereType<BreaklineEntity>().single;
    expect(bl.points.length, 2);
    expect(bl.points.last.distanceTo(const Pt(30, 10)), lessThan(1e-6));
  });
}
