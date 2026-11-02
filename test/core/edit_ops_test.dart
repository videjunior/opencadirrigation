import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tools/edit_commands.dart';
import 'package:opencadirrigation/app/tools/tools.dart';
import 'package:opencadirrigation/core/model/edit_ops.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

class _Host implements ToolHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The geometry edits of 1.6.0 (CAD-26): join, explode, fillet, chamfer,
/// stretch, break at two points and convert to area, in the core and as
/// undo steps of the editor with their labels in the history.
void main() {
  group('fillet: the simple circular curve (T = R·tan(Δ/2), L = R·Δ, E = R·(sec(Δ/2) − 1))', () {
    test('a right corner with R = 2: tangent points 2 m from the corner, the arc π m long', () {
      final out = filletVertex([const Pt(-10, 0), Pt.zero, const Pt(0, 10)], 1, 2)!;
      expect(out.first, const Pt(-10, 0));
      expect(out.last, const Pt(0, 10));
      final arc = out.sublist(1, out.length - 1);
      expect(arc.first.distanceTo(const Pt(-2, 0)), lessThan(1e-12));
      expect(arc.last.distanceTo(const Pt(0, 2)), lessThan(1e-12));
      for (final p in arc) {
        expect(p.distanceTo(const Pt(-2, 2)), closeTo(2, 1e-9), reason: 'on the circle of the curve');
      }
      // sampled every 10° at most: the chord error stays below 0.2 %
      expect(polylineLength(arc), closeTo(math.pi, math.pi * 0.002));
    });

    test('an interior angle of 60° (Δ = 120°), R = 1: T = √3, E = 1', () {
      final ua = const Pt(1, 0), ub = Pt.polar(1, math.pi / 3);
      final f = filletBetween(Pt.zero, ua, ub, 1)!;
      expect(f.ta.distanceTo(Pt.zero), closeTo(math.sqrt(3), 1e-12));
      expect(f.tb.distanceTo(Pt.zero), closeTo(math.sqrt(3), 1e-12));
      expect(f.center.distanceTo(Pt.zero) - f.radius, closeTo(1, 1e-12), reason: 'external distance E = R(sec 60° − 1) = 1');
      expect(f.sweepRad.abs(), closeTo(2 * math.pi / 3, 1e-12), reason: 'the arc turns by the deflection Δ');
      expect(filletBetween(Pt.zero, ua, const Pt(-1, 0), 1), isNull, reason: 'sides in line');
    });

    test('a radius too large for the sides, the ends of an open polyline and closed outlines', () {
      final pts = [const Pt(-1, 0), Pt.zero, const Pt(0, 10)];
      expect(filletVertex(pts, 1, 2), isNull, reason: 'the first side is 1 m long, the tangent 2 m');
      expect(filletVertex(pts, 0, 0.5), isNull, reason: 'an end of an open polyline is no corner');
      final square = [Pt.zero, const Pt(10, 0), const Pt(10, 10), const Pt(0, 10)];
      final round = filletVertex(square, 0, 1, closed: true)!;
      expect(round.length, greaterThan(square.length));
      expect(round.any((p) => p == Pt.zero), isFalse, reason: 'the corner is gone');
    });

    test('chamfer: the corner cut d1 and d2 along the sides', () {
      expect(chamferVertex([const Pt(-10, 0), Pt.zero, const Pt(0, 10)], 1, 2, 3), [const Pt(-10, 0), const Pt(-2, 0), const Pt(0, 3), const Pt(0, 10)]);
      expect(chamferVertex([const Pt(-1, 0), Pt.zero, const Pt(0, 10)], 1, 2, 3), isNull);
    });
  });

  group('join, explode and outlines', () {
    test('four lines in any direction become a closed square; pipes join only with their kind', () {
      final lines = [
        LineEntity(id: 'a', a: Pt.zero, b: const Pt(10, 0)),
        LineEntity(id: 'b', a: const Pt(10, 10), b: const Pt(10, 0)),
        LineEntity(id: 'c', a: const Pt(10, 10), b: const Pt(0, 10)),
        LineEntity(id: 'd', a: Pt.zero, b: const Pt(0, 10)),
      ];
      final chains = joinChains(lines, 1e-6);
      expect(chains.length, 1);
      final pl = joinedEntity(chains.single, 1e-6) as PolylineEntity;
      expect(pl.closed, isTrue);
      expect(pl.points.length, 4);
      expect(pl.id, 'a');
      expect(pl.area, closeTo(100, 1e-9));
      final p1 = PipeEntity(id: 'p1', points: [Pt.zero, const Pt(5, 0)], scope: HydraulicScope.zone, pipeSpecId: 'x');
      final p2 = PipeEntity(id: 'p2', points: [const Pt(5, 0), const Pt(9, 3)], scope: HydraulicScope.zone, pipeSpecId: 'x');
      final p3 = PipeEntity(id: 'p3', points: [const Pt(9, 3), const Pt(9, 9)], scope: HydraulicScope.zone, pipeSpecId: 'y');
      final joined = joinChains([p1, p2, p3], 1e-6);
      expect(joined.single.members.map((e) => e.id), ['p1', 'p2'], reason: 'another catalogue item is another kind');
      expect((joinedEntity(joined.single, 1e-6) as PipeEntity).points, [Pt.zero, const Pt(5, 0), const Pt(9, 3)]);
      expect(joinChains([p1, p2], 1e-6, blocked: (p) => p == const Pt(5, 0)), isEmpty, reason: 'a valve on the joint');
    });

    test('explode: a closed polyline into its lines, a pipe into its segments, a lateral keeps its outlets', () {
      var n = 0;
      String id() => 'n${n++}';
      final rect = PolylineEntity(id: 'r', points: [Pt.zero, const Pt(4, 0), const Pt(4, 2), const Pt(0, 2)], closed: true);
      final lines = explodeEntity(rect, id)!;
      expect(lines.length, 4);
      expect(lines.whereType<LineEntity>().map((l) => l.length).fold(0.0, (a, b) => a + b), closeTo(12, 1e-12));
      expect(lines.first.id, 'r');
      final pipe = PipeEntity(id: 'p', points: [Pt.zero, const Pt(10, 0), const Pt(10, 10)], scope: HydraulicScope.zone);
      expect(explodeEntity(pipe, id)!.length, 2);
      final lat = SpraylineEntity(id: 's', points: [Pt.zero, const Pt(10, 0), const Pt(10, 10)], outletSpecId: 'micro', spacing: 2, offset: 1);
      final parts = explodeEntity(lat, id)!.cast<SpraylineEntity>();
      expect(parts.fold(0, (a, s) => a + s.outletCount), lat.outletCount);
      expect(explodeEntity(LineEntity(id: 'l', a: Pt.zero, b: const Pt(1, 0)), id), isNull);
      expect(explodeEntity(HatchEntity(id: 'h', points: [Pt.zero, const Pt(1, 0), const Pt(1, 1)]), id)!.single, isA<PolylineEntity>());
    });

    test('the outline of an area: a circle as a polygon of 64 sides, area (N/2)·r²·sin(2π/N)', () {
      final ring = areaOutline(CircleEntity(id: 'c', center: Pt.zero, radius: 10))!;
      expect(ring.length, circleAreaSides);
      expect(polygonArea(ring).abs(), closeTo(32 * 100 * math.sin(math.pi / 32), 1e-9));
      expect(
        areaOutline(PolylineEntity(id: 'o', points: [Pt.zero, const Pt(1, 0), const Pt(1, 1)])),
        isNull,
        reason: 'open',
      );
      final meets = areaOutline(PolylineEntity(id: 'm', points: [Pt.zero, const Pt(1, 0), const Pt(1, 1), const Pt(1e-9, 0)]), tol: 1e-6)!;
      expect(meets.length, 3, reason: 'ends that meet close it');
    });
  });

  group('stretch and break', () {
    test('stretch: the vertices inside move, an item wholly inside moves, the rest stays', () {
      final w = const Bounds(8, -1, 12, 11);
      final pl = PolylineEntity(id: 'p', points: [Pt.zero, const Pt(10, 0), const Pt(10, 10), const Pt(0, 10)]);
      final s = stretchEntity(pl, w, const Pt(5, 0)) as PolylineEntity;
      expect(s.points, [Pt.zero, const Pt(15, 0), const Pt(15, 10), const Pt(0, 10)]);
      expect(pl.points[1], const Pt(10, 0), reason: 'the original is untouched');
      expect(stretchEntity(JunctionEntity(id: 'j', position: const Pt(9, 5)), w, const Pt(5, 0))!.bounds.minX, 14);
      expect(stretchEntity(LineEntity(id: 'l', a: const Pt(-5, 0), b: const Pt(-1, 0)), w, const Pt(5, 0)), isNull);
    });

    test('break: the part between two points goes; a circle keeps an arc, a closed outline opens', () {
      var n = 0;
      String id() => 'n${n++}';
      final l = LineEntity(id: 'l', a: Pt.zero, b: const Pt(10, 0));
      final two = breakEntity(l, const Pt(3, 1), const Pt(7, -1), id)!.cast<LineEntity>();
      expect(two.map((e) => (e.a.x, e.b.x)), [(0.0, 3.0), (7.0, 10.0)]);
      final one = breakEntity(l, Pt.zero, const Pt(4, 0), id)!.cast<LineEntity>();
      expect(one.map((e) => (e.a.x, e.b.x)), [(4.0, 10.0)], reason: 'from the end: shortened');
      expect(breakEntity(l, const Pt(5, 0), const Pt(5, 0), id)!.length, 2, reason: 'one point: split');
      expect(breakEntity(l, Pt.zero, const Pt(10, 0), id), isNull, reason: 'all of it is a delete, not a break');
      final arc = breakEntity(CircleEntity(id: 'c', center: Pt.zero, radius: 5), const Pt(5, 0), const Pt(0, 5), id)!.single as ArcEntity;
      expect(arc.sweepRad, closeTo(1.5 * math.pi, 1e-12), reason: 'the quarter from (5,0) to (0,5) counter-clockwise goes');
      expect(arc.startPoint.distanceTo(const Pt(0, 5)), lessThan(1e-9));
      final sq = PolylineEntity(id: 's', points: [Pt.zero, const Pt(10, 0), const Pt(10, 10), const Pt(0, 10)], closed: true);
      final open = breakEntity(sq, const Pt(4, 0), const Pt(6, 0), id)!.single as PolylineEntity;
      expect(open.closed, isFalse);
      expect(open.length, closeTo(38, 1e-9));
      expect(open.points.first, const Pt(6, 0));
      expect(open.points.last, const Pt(4, 0));
      expect(breakEntity(AreaEntity(id: 'a', points: sq.points), const Pt(4, 0), const Pt(6, 0), id), isNull);
    });
  });

  group('in the editor: one undo step each, with its label', () {
    late ProjectController c;
    setUp(() {
      setPref('lang', 'en');
      c = ProjectController()..autosaveEnabled = false;
      c.newProject();
      c.camera.size = const Size(800, 600);
      c.camera.center = const Pt(5, 5);
      c.camera.scale = 20;
      c.snap.enabled = false;
    });

    String lastLabel() => c.historyEntries.where((h) => h.current).single.label;

    test('join, explode and convert to area, undone', () {
      c.addEntities([
        LineEntity(id: 'a', a: Pt.zero, b: const Pt(10, 0)),
        LineEntity(id: 'b', a: const Pt(10, 0), b: const Pt(10, 10)),
        LineEntity(id: 'c', a: const Pt(10, 10), b: const Pt(0, 10)),
        LineEntity(id: 'd', a: const Pt(0, 10), b: Pt.zero),
      ]);
      c.selectAll();
      expect(c.joinSelected(), 4);
      expect(lastLabel(), 'hist.join|4');
      final pl = c.project.entities.single as PolylineEntity;
      expect(pl.closed, isTrue);
      expect(c.selection, {pl.id});
      expect(c.convertSelectedToArea(), 1);
      expect(lastLabel(), 'hist.toArea|1');
      final area = c.project.entities.single as AreaEntity;
      expect(area.area, closeTo(100, 1e-9));
      c.undo();
      expect(c.project.entities.single, isA<PolylineEntity>());
      c.select([pl.id]);
      expect(c.explodeSelected(), 1);
      expect(lastLabel(), 'hist.explode|1');
      expect(c.project.entities.whereType<LineEntity>().length, 4);
      expect(c.project.entities.map((e) => e.id).toSet().length, 4, reason: 'every piece has its own id');
      c.undo();
      c.undo();
      expect(c.project.entities.length, 4, reason: 'back to the four lines');
    });

    test('fillet and chamfer: two lines, a vertex of a pipe; refusals tell why', () {
      c.addEntities([LineEntity(id: 'h', a: const Pt(-10, 0), b: const Pt(1, 0)), LineEntity(id: 'v', a: const Pt(0, -1), b: const Pt(0, 10))]);
      c.editSettings.filletRadius = 2;
      expect(c.cornerAt('h', const Pt(-5, 0), 'v', const Pt(0, 5)), isTrue);
      expect(lastLabel(), 'hist.fillet');
      expect((c.project.byId('h') as LineEntity).b.distanceTo(const Pt(-2, 0)), lessThan(1e-9), reason: 'trimmed to the tangent point');
      expect((c.project.byId('v') as LineEntity).a.distanceTo(const Pt(0, 2)), lessThan(1e-9));
      final arc = c.project.entities.whereType<ArcEntity>().single;
      expect(arc.radius, 2);
      expect(arc.center.distanceTo(const Pt(-2, 2)), lessThan(1e-9));
      c.undo();
      // radius 0: a sharp corner, both lines meet at the crossing
      c.editSettings.filletRadius = 0;
      expect(c.cornerAt('h', const Pt(-5, 0), 'v', const Pt(0, 5)), isTrue);
      expect((c.project.byId('h') as LineEntity).b, Pt.zero);
      expect((c.project.byId('v') as LineEntity).a, Pt.zero);
      c.undo();
      // a chamfer of 1 and 3
      c.editSettings
        ..chamferDistance1 = 1
        ..chamferDistance2 = 3;
      expect(c.cornerAt('h', const Pt(-5, 0), 'v', const Pt(0, 5), chamfer: true), isTrue);
      expect(lastLabel(), 'hist.chamfer');
      final cut = c.project.entities.whereType<LineEntity>().where((l) => l.id != 'h' && l.id != 'v').single;
      expect({cut.a, cut.b}, {const Pt(-1, 0), const Pt(0, 3)});
      // the corner of a mainline pipe: the vertex becomes the arc
      final pipe = PipeEntity(id: 'p', points: [const Pt(0, 20), const Pt(20, 20), const Pt(20, 40)], scope: HydraulicScope.mainline);
      c.addEntity(pipe);
      c.editSettings.filletRadius = 5;
      expect(c.cornerAt('p', const Pt(10, 20), 'p', const Pt(20, 30)), isTrue);
      final round = c.project.byId('p') as PipeEntity;
      expect(round.points.first, const Pt(0, 20));
      expect(round.points.last, const Pt(20, 40));
      expect(round.points.contains(const Pt(20, 20)), isFalse);
      expect(c.results, isNull);
      // two sides that do not meet at a vertex
      expect(c.cornerAt('p', const Pt(5, 20), 'p', const Pt(20, 39)), isFalse);
      expect(c.lastMessage, c.t('edt.filletFailed'));
    });

    test('two pipe ends filleted stay joined: the arc becomes vertices of the first', () {
      c.addEntities([
        PipeEntity(id: 'a', points: [const Pt(-20, 0), const Pt(-3, 0)], scope: HydraulicScope.mainline),
        PipeEntity(id: 'b', points: [const Pt(0, 3), const Pt(0, 20)], scope: HydraulicScope.mainline),
      ]);
      c.editSettings.filletRadius = 2;
      expect(c.cornerAt('a', const Pt(-10, 0), 'b', const Pt(0, 10)), isTrue);
      final a = c.project.byId('a') as PipeEntity, b = c.project.byId('b') as PipeEntity;
      expect(a.points.last.distanceTo(b.points.first), lessThan(1e-9), reason: 'joined');
      expect(c.project.entities.whereType<ArcEntity>(), isEmpty);
    });

    test('stretch a window and break at two points', () {
      c.addEntities([
        PipeEntity(id: 'p', points: [Pt.zero, const Pt(10, 0)], scope: HydraulicScope.zone),
        PipeEntity(id: 'q', points: [const Pt(10, 0), const Pt(10, 10)], scope: HydraulicScope.zone),
        LineEntity(id: 'far', a: const Pt(30, 0), b: const Pt(40, 0)),
      ]);
      expect(c.stretchWindow(const Bounds(8, -1, 12, 1), const Pt(2, 0)), 2);
      expect(lastLabel(), 'hist.stretch|2');
      expect((c.project.byId('p') as PipeEntity).points.last, const Pt(12, 0));
      expect((c.project.byId('q') as PipeEntity).points.first, const Pt(12, 0), reason: 'the joint inside the window kept together');
      expect((c.project.byId('q') as PipeEntity).points.last, const Pt(10, 10));
      expect(c.breakBetween('far', const Pt(32, 0), const Pt(35, 0)), isTrue);
      expect(lastLabel(), 'hist.break');
      expect(c.project.entities.whereType<LineEntity>().map((l) => l.length).toList()..sort(), [2, 5]);
      c.undo();
      expect((c.project.byId('far') as LineEntity).length, 10);
    });

    test('the tools: stretch by a dragged window, fillet by two clicks with a typed radius, break by two clicks', () {
      c.addEntities([LineEntity(id: 'h', a: const Pt(-10, 0), b: const Pt(1, 0)), LineEntity(id: 'v', a: const Pt(0, -1), b: const Pt(0, 10))]);
      final st = createTool(ToolId.stretch, c, _Host());
      st.onDown(const Pt(-11, -1));
      st.onMove(const Pt(-9, 1), dragging: true);
      st.onUp(const Pt(-9, 1));
      st.onDown(const Pt(-10, 0));
      st.onDown(const Pt(-12, 0));
      expect((c.project.byId('h') as LineEntity).a, const Pt(-12, 0));
      final fi = createTool(ToolId.fillet, c, _Host());
      expect(fi.onInput('1.5'), isTrue);
      expect(c.editSettings.filletRadius, 1.5);
      fi.onDown(const Pt(-5, 0));
      fi.onDown(const Pt(0, 5));
      expect(c.project.entities.whereType<ArcEntity>().single.radius, 1.5);
      final br = createTool(ToolId.breakTwo, c, _Host());
      br.onDown(const Pt(-8, 0.01));
      br.onDown(const Pt(-6, 0));
      final pieces = c.project.entities.whereType<LineEntity>().where((l) => l.a.y == 0 && l.b.y == 0).toList();
      expect(pieces.length, 2, reason: 'the horizontal line has a gap from x = -8 to -6');
    });
  });
}
