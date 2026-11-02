import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tools/tools.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/split.dart';

class _Host implements ToolHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Trim and extend against every outline (CAD-11): the closing side of a
/// closed polyline or an area, circles and arcs (exactly, not their
/// polyline) and splines along their drawn curve.
void main() {
  final rect = PolylineEntity(id: 'r', points: [Pt.zero, const Pt(10, 0), const Pt(10, 10), const Pt(0, 10)], closed: true);

  group('cut edges', () {
    test('extending to the closing side of a closed rectangle (the probe of the sweep)', () {
      final left = LineEntity(id: 'l', a: const Pt(5, 5), b: const Pt(3, 5));
      expect(extendLinearEntity(left, const Pt(3, 5), const [], edges: [CutEdge.of(rect)!]), isTrue);
      expect(left.b, const Pt(0, 5));
      final right = LineEntity(id: 'l2', a: const Pt(5, 5), b: const Pt(7, 5));
      expect(extendLinearEntity(right, const Pt(7, 5), const [], edges: [CutEdge.of(rect)!]), isTrue);
      expect(right.b, const Pt(10, 5));
      // an open path keeps its old behaviour: no closing side
      final open = LineEntity(id: 'l3', a: const Pt(5, 5), b: const Pt(3, 5));
      expect(extendLinearEntity(open, const Pt(3, 5), [rect.points]), isFalse);
    });

    test('circles and arcs are cut exactly; a ray that misses the sweep of an arc goes on', () {
      final circle = CutEdge.circle(const Pt(20, 0), 5);
      expect(circle.rayHit(Pt.zero, const Pt(1, 0)), closeTo(15, 1e-12));
      expect(circle.rayHit(const Pt(20, 0), const Pt(0, 1)), closeTo(5, 1e-12), reason: 'from the centre: the far side');
      expect(circle.rayHit(Pt.zero, const Pt(0, 1)), isNull);
      // the right half of the circle, from (20,-5) through (25,0) to (20,5)
      final arc = CutEdge.arc(const Pt(20, 0), 5, -math.pi / 2, math.pi);
      expect(arc.rayHit(Pt.zero, const Pt(1, 0)), closeTo(25, 1e-12), reason: 'x = 15 is on the missing half');
      // the same half drawn clockwise from (20,5)
      final cw = CutEdge.arc(const Pt(20, 0), 5, math.pi / 2, -math.pi);
      expect(cw.rayHit(Pt.zero, const Pt(1, 0)), closeTo(25, 1e-12));
      final hits = circle.crossings([Pt.zero, const Pt(40, 0)]);
      expect(hits.map((p) => p.x).toList()..sort(), [15, 25]);
      final ofArc = CutEdge.of(ArcEntity(id: 'a', center: const Pt(20, 0), radius: 5, startRad: -math.pi / 2, sweepRad: math.pi))!;
      expect(ofArc.crossings([Pt.zero, const Pt(40, 0)]).map((p) => p.x), [25]);
    });

    test('a spline edge is its drawn curve, not the polygon of its fit points', () {
      final s = SplineEntity(id: 's', points: [const Pt(10, -10), const Pt(12, 0), const Pt(10, 10)]);
      final l = LineEntity(id: 'l', a: const Pt(0, 5), b: const Pt(2, 5));
      expect(extendLinearEntity(l, const Pt(2, 5), const [], edges: [CutEdge.of(s)!]), isTrue);
      expect(s.distanceTo(l.b), lessThan(1e-6), reason: 'on the curve');
      expect((l.b.x - 11).abs(), greaterThan(0.05), reason: 'the chord between the fit points is at x = 11');
    });
  });

  group('in the editor', () {
    late ProjectController c;
    setUp(() {
      setPref('lang', 'en');
      c = ProjectController()..autosaveEnabled = false;
      c.newProject();
      c.camera.size = const Size(800, 600);
      c.camera.center = const Pt(10, 5);
      c.camera.scale = 10;
    });

    test('extending a pipe to the closing side of an area and of a closed polyline', () {
      c.addEntity(AreaEntity(id: 'area', points: [Pt.zero, const Pt(10, 0), const Pt(10, 10), const Pt(0, 10)]));
      c.addEntity(PipeEntity(id: 'p', points: [const Pt(5, 5), const Pt(3, 5)], scope: HydraulicScope.zone));
      expect(c.extendAt('p', const Pt(3, 5)), isTrue);
      expect((c.project.byId('p') as PipeEntity).points.last, const Pt(0, 5));
      c.addEntity(rect.clone(newId: 'r2').translated(const Pt(0, 20)));
      c.addEntity(LineEntity(id: 'l', a: const Pt(5, 25), b: const Pt(4, 25)));
      c.select(['r2']);
      expect(c.extendAt('l', const Pt(4, 25)), isTrue);
      expect((c.project.byId('l') as LineEntity).b, const Pt(0, 25));
    });

    test('trimming against a circle; Shift picks the circle as the cutting edge', () {
      c.addEntity(CircleEntity(id: 'c', center: const Pt(20, 0), radius: 5));
      c.addEntity(LineEntity(id: 'l', a: Pt.zero, b: const Pt(40, 0)));
      c.addEntity(LineEntity(id: 'far', a: const Pt(30, -10), b: const Pt(30, 10)));
      final tr = createTool(ToolId.trim, c, _Host());
      tr.onDown(const Pt(25, 0.01), shift: true);
      tr.onDown(const Pt(15, 0.01), shift: true);
      expect(c.selection, isEmpty, reason: 'both clicks hit the circle: picked, then unpicked');
      tr.onDown(const Pt(20, 5.01), shift: true);
      expect(c.selection, {'c'});
      expect(c.trimAt('l', const Pt(20, 0)), isTrue);
      final pieces = c.project.entities.whereType<LineEntity>().where((e) => e.a.y == 0 && e.b.y == 0).toList();
      expect(pieces.map((e) => (e.a.x, e.b.x)).toList()..sort((a, b) => a.$1.compareTo(b.$1)), [(0.0, 15.0), (25.0, 40.0)], reason: 'only the circle cuts: the line at x = 30 is no edge');
    });
  });
}
