import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/shortcuts.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tools/edit_commands.dart';
import 'package:opencadirrigation/app/tools/edit_tools.dart';
import 'package:opencadirrigation/app/tools/tools.dart';
import 'package:opencadirrigation/app/tools/typed_point.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/units.dart';

/// Records what the tools ask of the widget layer.
class _Host implements ToolHost {
  String status = '';
  @override
  void setStatus(String text) => status = text;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The editing tools of 1.6.0 driven directly, without the canvas widget.
void main() {
  late ProjectController c;
  late _Host host;

  setUp(() {
    setPref('lang', 'en');
    c = ProjectController()..autosaveEnabled = false;
    c.newProject();
    c.camera.size = const Size(800, 600);
    c.camera.center = Pt.zero;
    c.camera.scale = 10;
    c.snap.enabled = false;
    host = _Host();
  });

  Tool tool(ToolId id) => createTool(id, c, host);

  void paint(Tool t) {
    final rec = PictureRecorder();
    t.paint(Canvas(rec), c.camera);
    rec.endRecording().dispose();
  }

  /// A point typed on the command line while [t] waits for one.
  Pt typed(Tool t, String text) => parseTypedPoint(text, reference: t.referencePoint, cursor: t.cursor)!;

  group('a polyline in progress is not lost (CAD-10)', () {
    void clicks(Tool t, List<Pt> pts) {
      for (final p in pts) {
        t.onMove(p);
        t.onDown(p);
      }
    }

    test('Esc keeps a traced outline of 40 vertices; a stroke too short for its item is dropped', () {
      final pl = tool(ToolId.polyline);
      clicks(pl, [for (var i = 0; i < 40; i++) Pt(i * 1.0, (i % 2) * 3.0)]);
      pl.onKey('Escape');
      expect(c.project.entities.whereType<PolylineEntity>().single.points.length, 40);
      expect(pl.idle, isTrue, reason: 'Esc then leaves the tool');
      final ar = tool(ToolId.area);
      clicks(ar, [Pt.zero, const Pt(5, 0)]);
      ar.onKey('Escape');
      expect(c.project.entities.whereType<AreaEntity>(), isEmpty, reason: 'two points are no area');
      // the Cancel button drops the stroke (the canvas cancels the tool)
      final p2 = tool(ToolId.polyline);
      clicks(p2, [Pt.zero, const Pt(9, 9), const Pt(9, 0)]);
      p2.cancel();
      expect(c.project.entities.whereType<PolylineEntity>().length, 1);
    });

    test('C closes the stroke and U takes back its last point, before the aliases of those letters', () {
      final pl = tool(ToolId.polyline);
      expect(pl.onInput('C'), isFalse, reason: 'nothing in progress: C is the circle alias');
      expect(pl.onInput('U'), isFalse, reason: 'nothing in progress: U is undo');
      clicks(pl, [Pt.zero, const Pt(10, 0)]);
      expect(pl.onInput('C'), isTrue, reason: 'taken: two points cannot close');
      expect(c.lastMessage, c.t('edt.closeNeeds3'));
      clicks(pl, [const Pt(10, 10), const Pt(20, 20)]);
      expect(pl.onInput('U'), isTrue);
      expect((pl as PolyTool).pts.last, const Pt(10, 10));
      expect(pl.onInput('C'), isTrue);
      final closed = c.project.entities.whereType<PolylineEntity>().single;
      expect(closed.closed, isTrue);
      expect(closed.points, [Pt.zero, const Pt(10, 0), const Pt(10, 10)]);
      // a pipe closes as a ring: its first point again at the end
      final pipe = tool(ToolId.mainPipe);
      clicks(pipe, [const Pt(0, 50), const Pt(30, 50), const Pt(30, 80)]);
      expect(pipe.onInput('C'), isTrue);
      final ring = c.project.entities.whereType<PipeEntity>().single;
      expect(ring.points.first, ring.points.last);
      expect(ring.points.length, 4);
      // an area closes by itself: C finishes it
      final ar = tool(ToolId.area);
      clicks(ar, [const Pt(0, 100), const Pt(20, 100), const Pt(20, 120)]);
      expect(ar.onInput('C'), isTrue);
      expect(c.project.entities.whereType<AreaEntity>().single.points.length, 3);
      // the leader has no closed form: C is its alias
      final le = tool(ToolId.leader);
      clicks(le, [Pt.zero, const Pt(1, 1), const Pt(2, 0)]);
      expect(le.onInput('C'), isFalse);
    });

    test('a change of tool keeps the stroke of a drawing tool; a dialog tool drops it without opening its dialog', () {
      final pl = tool(ToolId.zonePipe);
      clicks(pl, [Pt.zero, const Pt(10, 0), const Pt(10, 10)]);
      pl.leave();
      expect(c.project.entities.whereType<PipeEntity>().single.points.length, 3);
      expect(pl.idle, isTrue);
      final bl = tool(ToolId.block);
      clicks(bl, [Pt.zero, const Pt(10, 0), const Pt(10, 10)]);
      bl.leave();
      expect(c.project.entities.length, 1, reason: 'no lateral block without its dialog');
      final pr = tool(ToolId.profile);
      clicks(pr, [Pt.zero, const Pt(10, 0)]);
      pr.leave();
      expect(c.profilePath, isNull, reason: 'the profile only opens with Enter');
    });
  });

  group('measure: the result stays, running length, area and perimeter (CAD-33)', () {
    void clicks(Tool t, List<Pt> pts) {
      for (final p in pts) {
        t.onMove(p);
        t.onDown(p);
      }
    }

    test('two points: the distance stays as the last measurement after the pointer moves on', () {
      final me = tool(ToolId.measure);
      clicks(me, [Pt.zero, const Pt(3, 4)]);
      expect(host.status, 'Δ = 5.000 m  (Δx 3.00, Δy 4.00, 53.1°)');
      me.onMove(const Pt(50, 50));
      paint(me);
      final last = c.editSettings.lastMeasure!;
      expect(last.text(c), 'Δ = 5.000 m  (Δx 3.00, Δy 4.00, 53.1°)');
      expect(c.project.entities, isEmpty, reason: 'measuring draws nothing in the project');
    });

    test('M: the running length of several points; A: area and perimeter of an outline', () {
      final me = tool(ToolId.measure);
      expect(me.onInput('M'), isTrue);
      expect(c.editSettings.measureMode, MeasureMode.path);
      clicks(me, [Pt.zero, const Pt(10, 0), const Pt(10, 5)]);
      expect(c.editSettings.lastMeasure, isNull, reason: 'the path goes on until Enter');
      me.onKey('Enter');
      expect(c.editSettings.lastMeasure!.length, 15);
      expect(c.editSettings.lastMeasure!.text(c), 'L = 15.00 m over 2 segments');
      expect(me.onInput('A'), isTrue);
      clicks(me, [Pt.zero, const Pt(20, 0), const Pt(20, 10)]);
      me.onMove(const Pt(0, 10));
      paint(me);
      expect(host.status, contains('200.0 m²'), reason: 'the area follows the cursor');
      clicks(me, [const Pt(0, 10)]);
      expect(me.onInput('C'), isTrue, reason: 'C closes the outline');
      final m = c.editSettings.lastMeasure!;
      expect(m.area, 200);
      expect(m.length, 60);
      expect(m.text(c), 'Area = 200.0 m² (0.0200 ha) · perimeter = 60.00 m');
      // in feet: square feet and acres
      c.project.params.units = c.project.params.units.copyWith(length: LengthUnit.ft);
      expect(m.text(c), startsWith('Area = 2152.8 ft² (0.0494 ac)'));
      expect(me.onInput('D'), isTrue);
      expect(c.editSettings.measureMode, MeasureMode.distance);
    });
  });

  group('values typed at the step of a tool (CAD-09)', () {
    test('rotate: a number after the base point is the angle, with or without the reference point', () {
      c.addEntity(LineEntity(id: 'l', a: Pt.zero, b: const Pt(10, 0)));
      c.select(['l']);
      final ro = tool(ToolId.rotate);
      expect(ro.onInput('45'), isFalse, reason: 'no base point yet: not the angle');
      ro.onDown(Pt.zero);
      paint(ro);
      expect(host.status, c.t('edt.typeAngle'));
      expect(ro.onInput('@3,4'), isFalse, reason: 'a point is a point');
      expect(ro.onInput('90'), isTrue);
      var l = c.project.byId('l') as LineEntity;
      expect(l.b.distanceTo(const Pt(0, 10)), lessThan(1e-9));
      // base point, reference point, then the angle typed: 45°, not the
      // direction of a point 45 m along the cursor
      ro.onDown(Pt.zero);
      ro.onDown(const Pt(0, 10));
      ro.onMove(const Pt(-3, 0));
      expect(ro.onInput('45'), isTrue);
      l = c.project.byId('l') as LineEntity;
      expect(l.b.x, closeTo(-10 * 0.7071067811865476, 1e-9));
      expect(l.b.y, closeTo(10 * 0.7071067811865476, 1e-9));
      expect(ro.referencePoint, isNull, reason: 'the rotation is done');
    });

    test('scale: a number after the base point is the factor itself', () {
      c.addEntity(LineEntity(id: 'l', a: Pt.zero, b: const Pt(10, 0)));
      c.select(['l']);
      final sc = tool(ToolId.scale);
      sc.onDown(Pt.zero);
      paint(sc);
      expect(host.status, c.t('edt.typeFactor'));
      expect(sc.onInput('2'), isTrue);
      expect((c.project.byId('l') as LineEntity).b, const Pt(20, 0));
      // with a reference point 4 m away, 3 is still a factor of 3 (not 3/4)
      sc.onDown(Pt.zero);
      sc.onDown(const Pt(4, 0));
      expect(sc.onInput('3'), isTrue);
      expect((c.project.byId('l') as LineEntity).b.x, closeTo(60, 1e-9));
      final n = c.historyEntries.length;
      sc.onDown(Pt.zero);
      expect(sc.onInput('-1'), isTrue, reason: 'taken, refused with a message');
      expect(c.lastMessage, c.t('edt.badValue'));
      expect(c.historyEntries.length, n);
    });

    test('offset: a number at any step is the distance, in the display unit', () {
      c.addEntity(LineEntity(id: 'l', a: Pt.zero, b: const Pt(10, 0)));
      final off = tool(ToolId.offset);
      off.onMove(const Pt(5, 5));
      paint(off);
      expect(host.status, contains(c.t('edt.typeDistance')));
      expect(off.onInput('3'), isTrue);
      expect(c.toolSettings.offsetDistance, 3);
      off.onDown(const Pt(5, 0.1));
      off.onDown(const Pt(5, 5));
      final copy = c.project.entities.whereType<LineEntity>().last;
      expect(copy.a.y, closeTo(3, 1e-9));
      c.project.params.units = c.project.params.units.copyWith(length: LengthUnit.ft);
      expect(off.onInput('10'), isTrue);
      expect(c.toolSettings.offsetDistance, closeTo(3.048, 1e-12));
    });
  });

  group('move and copy by base point (CAD-06)', () {
    test('aliases: M is Move, CO/CP/COPY the Copy tool; the clipboard keeps Ctrl+C and COPYCLIP', () {
      for (final a in ['M', 'MOVE', 'MOVER']) {
        expect(commandAliases[a], ToolId.move, reason: a);
      }
      for (final a in ['CO', 'CP', 'COPY', 'COPIAR']) {
        expect(commandAliases[a], ToolId.copy, reason: a);
      }
      expect(commandAliases['COPYCLIP'], CadAction.copy);
      expect(aliasOf(ToolId.move), 'M');
      expect(aliasOf(ToolId.copy), 'CO');
    });

    test('move: a click picks, then base point and destination; typed @dx,dy, polar and a bare distance', () {
      c.addEntity(LineEntity(id: 'l', a: Pt.zero, b: const Pt(10, 0)));
      final mv = tool(ToolId.move);
      mv.onDown(const Pt(5, 0.1));
      expect(c.selection, {'l'}, reason: 'with nothing selected a click picks');
      mv.onDown(Pt.zero);
      expect(mv.referencePoint, Pt.zero);
      mv.onMove(const Pt(3, 4));
      paint(mv);
      expect(host.status, startsWith('Δx 3.00  Δy 4.00  d 5.00 m'));
      mv.onDown(const Pt(3, 4));
      final l = c.project.byId('l') as LineEntity;
      expect((l.a, l.b), (const Pt(3, 4), const Pt(13, 4)));
      expect(c.historyEntries.last.label, 'hist.move');
      // typed relative to the base point: @10,0
      mv.onDown(const Pt(3, 4));
      mv.onDown(typed(mv, '@10,0'));
      expect((c.project.byId('l') as LineEntity).a, const Pt(13, 4));
      // polar: 5 m at 90°
      mv.onDown(const Pt(13, 4));
      final polar = typed(mv, '@5<90');
      mv.onDown(polar);
      expect((c.project.byId('l') as LineEntity).a.distanceTo(const Pt(13, 9)), lessThan(1e-9));
      // a bare distance along the cursor
      final at = (c.project.byId('l') as LineEntity).a;
      mv.onDown(at);
      mv.onMove(at + const Pt(-100, 0));
      mv.onDown(typed(mv, '2'));
      expect((c.project.byId('l') as LineEntity).a.distanceTo(at + const Pt(-2, 0)), lessThan(1e-9));
      expect(c.project.entities.length, 1, reason: 'moves never copy');
    });

    test('move with Ctrl copies; the keep-original switch of rotate does not turn a move into a copy', () {
      c.addEntity(OutletEntity(id: 'o', position: Pt.zero, outletSpecId: 'micro'));
      c.select(['o']);
      c.toolSettings.copyOnTransform = true;
      final mv = tool(ToolId.move);
      mv.onDown(Pt.zero);
      mv.onDown(const Pt(2, 0));
      expect(c.project.entities.length, 1);
      expect((c.project.byId('o') as OutletEntity).position, const Pt(2, 0));
      mv.onDown(const Pt(2, 0), ctrl: true);
      mv.onDown(const Pt(2, 5), ctrl: true);
      expect(c.project.entities.length, 2);
      expect(c.project.entities.whereType<OutletEntity>().map((e) => e.position), containsAll([const Pt(2, 0), const Pt(2, 5)]));
    });

    test('copy repeats from the same base point until Enter, each copy one undo step, the originals stay selected', () {
      c.addEntity(LineEntity(id: 'l', a: Pt.zero, b: const Pt(4, 0)));
      c.select(['l']);
      final steps = c.historyEntries.length;
      final cp = tool(ToolId.copy);
      cp.onDown(Pt.zero);
      cp.onMove(const Pt(0, 3));
      paint(cp);
      expect(host.status, startsWith('Δx 0.00  Δy 3.00'));
      cp.onDown(const Pt(0, 3));
      cp.onDown(const Pt(0, 6));
      cp.onDown(typed(cp, '@0,9'));
      final lines = c.project.entities.whereType<LineEntity>().toList();
      expect(lines.length, 4);
      expect(lines.map((e) => e.a.y), [0, 3, 6, 9]);
      expect(c.selection, {'l'}, reason: 'the originals stay selected');
      expect(c.historyEntries.length, steps + 3);
      expect(c.historyEntries.last.label, 'hist.copy|1');
      cp.onKey('Enter');
      expect(c.activeTool, ToolId.select, reason: 'Enter ends the copies');
      c.undo();
      expect(c.project.entities.length, 3);
    });

    test('the tools have their labels, hints and a place in the history', () {
      for (final id in [ToolId.move, ToolId.copy]) {
        final t = tool(id);
        expect(t.hintKey, 'hint.${hintKeyOf(id)}');
        expect(c.t.has(t.hintKey), isTrue);
        expect(c.t.has('tool.${id.name}'), isTrue);
      }
      expect(displacementText(c, const Pt(0, -2)), contains('∠ 270.0°'));
    });
  });
}
