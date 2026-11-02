import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/canvas/snapping.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

import '../support/perf.dart';

void main() {
  // 4 px per metre and a 10 px tolerance: snaps reach 2.5 m
  ProjectController controller(List<Entity> entities) {
    final c = ProjectController();
    c.project = Project();
    c.camera.size = const Size(800, 600);
    c.camera.center = const Pt(50, 50);
    c.camera.scale = 4;
    c.addEntities(entities);
    return c;
  }

  void near(SnapResult s, String kind, Pt at) {
    expect(s.kind, kind);
    expect(s.point.distanceTo(at), lessThan(1e-6), reason: '${s.point.x},${s.point.y}');
  }

  test('intersection of two lines, of a line and a circle, of two circles', () {
    final c = controller([
      LineEntity(id: 'h', a: const Pt(0, 50), b: const Pt(100, 50)),
      LineEntity(id: 'v', a: const Pt(40, 0), b: const Pt(40, 100)),
      CircleEntity(id: 'k', center: const Pt(80, 50), radius: 10),
      CircleEntity(id: 'k2', center: const Pt(80, 64), radius: 10),
    ]);
    near(Snapper(c).snap(const Pt(40.8, 50.6)), 'intersection', const Pt(40, 50));
    near(Snapper(c).snap(const Pt(70.5, 50.4)), 'intersection', const Pt(70, 50));
    // circles centred 14 m apart, radius 10: they cross at y = 57
    final x = 80 + math.sqrt(100 - 49);
    near(Snapper(c).snap(Pt(x - 0.4, 57.3)), 'intersection', Pt(x, 57));
  });

  test('perpendicular and tangent from the previous point; quadrants and arcs', () {
    final c = controller([
      LineEntity(id: 'h', a: const Pt(0, 50), b: const Pt(100, 50)),
      CircleEntity(id: 'k', center: const Pt(50, 20), radius: 5),
      ArcEntity(id: 'a', center: const Pt(20, 80), radius: 6, startRad: 0, sweepRad: math.pi / 2),
    ]);
    near(Snapper(c).snap(const Pt(30.6, 51), reference: const Pt(30, 70)), 'perpendicular', const Pt(30, 50));
    // tangent from (50, 30) to the circle of centre (50, 20) and radius 5
    final alpha = math.acos(5 / 10);
    final t1 = const Pt(50, 20) + Pt.polar(5, math.pi / 2 - alpha);
    near(Snapper(c).snap(t1 + const Pt(0.3, -0.2), reference: const Pt(50, 30)), 'tangent', t1);
    near(Snapper(c).snap(const Pt(55.6, 20.3)), 'quadrant', const Pt(55, 20));
    near(Snapper(c).snap(const Pt(20.4, 79.6)), 'center', const Pt(20, 80));
    near(Snapper(c).snap(const Pt(25.8, 80.4)), 'endpoint', const Pt(26, 80));
    // no quadrant on the part of the circle the arc does not sweep
    expect(Snapper(c).snap(const Pt(14.2, 80.3)).kind, isNot('quadrant'));
  });

  test('extension beyond the end of a line, and polar tracking', () {
    final c = controller([LineEntity(id: 'h', a: const Pt(0, 50), b: const Pt(20, 50))]);
    near(Snapper(c).snap(const Pt(35, 50.8)), 'extension', const Pt(35, 50));
    c.snap.polarStepDeg = 30;
    // 31° from the reference: pulled onto 30°
    final ref = const Pt(60, 10);
    final raw = ref + Pt.polar(20, 31 * math.pi / 180);
    final s = Snapper(c).snap(raw, reference: ref);
    expect(s.kind, 'polar');
    expect((s.point - ref).angle * 180 / math.pi, closeTo(30, 1e-9));
    // 40°: too far from 30° and 60°, free
    expect(Snapper(c).snap(ref + Pt.polar(20, 40 * math.pi / 180), reference: ref).kind, 'none');
    expect(snapKindKey('45°'), 'snapk.lock45');
    expect(snapKindKey('intersection'), 'snapk.intersection');
  });

  test('long contours crossing by the cursor: their crossing, midpoints and vertices as on short lines, at once', () {
    // two 20 km contours of 20 001 vertices that cross at (50, 50), between
    // their vertices; every pair of their segments was once tested for a
    // crossing on each move of the cursor
    final across = [for (var i = 0; i <= 20000; i++) Pt(-9950.5 + i, 50)];
    final up = [for (var i = 0; i <= 20000; i++) Pt(50, -9950.5 + i)];
    final c = controller([
      ContourEntity(id: 'w', points: across, elevation: 1),
      ContourEntity(id: 's', points: up, elevation: 2),
      PolylineEntity(id: 'p', points: const [Pt(60, 60), Pt(70, 60), Pt(70, 70)]),
    ]);
    final sw = Stopwatch()..start();
    final x = Snapper(c).snap(const Pt(50.1, 50.1));
    expect(sw.elapsedMilliseconds, lessThan(perfBudgetMs(500)));
    near(x, 'intersection', const Pt(50, 50));
    near(Snapper(c).snap(const Pt(51.4, 50.2)), 'endpoint', const Pt(51.5, 50));
    // a short polyline as before: vertex, midpoint
    near(Snapper(c).snap(const Pt(70.4, 60.3)), 'endpoint', const Pt(70, 60));
    near(Snapper(c).snap(const Pt(65.2, 60.5)), 'midpoint', const Pt(65, 60));
    // the closing side of a closed outline still crosses
    final box = controller([
      PolylineEntity(id: 'b', points: const [Pt(0, 0), Pt(20, 0), Pt(20, 20), Pt(0, 20)], closed: true),
      LineEntity(id: 'l', a: const Pt(-10, 10), b: const Pt(10, 10)),
    ]);
    near(Snapper(box).snap(const Pt(0.5, 10.4)), 'intersection', const Pt(0, 10));
  }, tags: perfTag);
}
