import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tools/tools.dart';
import 'package:opencadirrigation/core/design/pivot.dart' show PivotKind;
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// Records what the tools ask of the widget layer.
class FakeHost implements ToolHost {
  final calls = <String>[];
  List<Pt>? polygon;
  List<Pt>? leader;
  Pt? textAt;
  Entity? elevationOf;
  String status = '';

  @override
  void showBlockDialog(List<Pt> p) {
    calls.add('block');
    polygon = p;
  }

  @override
  void showAutoheadDialog(List<Pt> p) {
    calls.add('autohead');
    polygon = p;
  }

  @override
  void showTextDialog(Pt position) {
    calls.add('text');
    textAt = position;
  }

  @override
  void showLeaderDialog(List<Pt> points) {
    calls.add('leader');
    leader = points;
  }

  @override
  void setStatus(String text) => status = text;

  @override
  void promptElevation(Entity e) {
    calls.add('elevation');
    elevationOf = e;
  }
}

/// Every drawing, editing and item tool driven directly (clicks, keys and
/// the preview paint), without the canvas widget.
void main() {
  late ProjectController c;
  late FakeHost host;

  setUp(() {
    setPref('lang', 'pt');
    c = ProjectController()..autosaveEnabled = false;
    c.newProject();
    c.camera.size = const Size(800, 600);
    c.camera.center = Pt.zero;
    c.camera.scale = 10;
    c.snap.enabled = false;
    host = FakeHost();
  });

  Tool tool(ToolId id) => createTool(id, c, host);

  /// Paints the tool's preview on a throw-away canvas.
  void paint(Tool t) {
    final rec = PictureRecorder();
    t.paint(Canvas(rec), c.camera);
    rec.endRecording().dispose();
  }

  void clicks(Tool t, List<Pt> pts) {
    for (final p in pts) {
      t.onMove(p);
      t.onDown(p);
    }
  }

  T only<T extends Entity>() => c.project.entities.whereType<T>().single;

  test('every tool has its id and a translated hint, and paints without data', () {
    final en = I18n('en'), pt = I18n('pt');
    for (final id in ToolId.values) {
      final t = tool(id);
      expect(t.id, id, reason: id.name);
      expect(t.hintKey, 'hint.${hintKeyOf(id)}', reason: id.name);
      expect(en.has(t.hintKey), isTrue, reason: t.hintKey);
      expect(pt(t.hintKey), isNot(t.hintKey), reason: t.hintKey);
      paint(t);
      t.onMove(const Pt(1, 1));
      paint(t);
      t.onKey('Escape');
      t.cancel();
      t.onDoubleClick(const Pt(1, 1));
      t.onUp(const Pt(1, 1));
    }
    final pan = tool(ToolId.pan);
    pan.onDown(const Pt(3, 3));
    expect(c.project.entities, isEmpty, reason: 'the pan tool only moves the view');
    expect(pan.usesSnap, isFalse);
    expect(tool(ToolId.trim).usesSnap, isFalse);
    expect(tool(ToolId.extend).usesSnap, isFalse);
  });

  group('drawing tools', () {
    test('line, polyline (Enter, double click, Backspace, Esc) and rectangle', () {
      clicks(tool(ToolId.line), [Pt.zero, const Pt(3, 4)]);
      final l = only<LineEntity>();
      expect((l.a, l.b), (Pt.zero, const Pt(3, 4)));
      expect(l.layer, c.drawingLayer);
      final pl = tool(ToolId.polyline);
      clicks(pl, [Pt.zero, Pt.zero, const Pt(10, 0), const Pt(10, 10), const Pt(20, 20)]);
      expect((pl as PolyTool).pts.length, 4, reason: 'a repeated click is ignored');
      pl.onKey('Backspace');
      expect(pl.referencePoint, const Pt(10, 10));
      pl.onMove(const Pt(15, 12));
      paint(pl);
      expect(host.status, startsWith('d = '));
      pl.onKey('Enter');
      expect(only<PolylineEntity>().points, [Pt.zero, const Pt(10, 0), const Pt(10, 10)]);
      final pl2 = tool(ToolId.polyline);
      clicks(pl2, [const Pt(0, 30), const Pt(5, 30)]);
      pl2.onDoubleClick(const Pt(5, 30));
      expect(c.project.entities.whereType<PolylineEntity>().length, 2);
      final pl3 = tool(ToolId.polyline);
      clicks(pl3, [const Pt(0, 40), const Pt(5, 40)]);
      pl3.onKey('Escape');
      pl3.onKey('Enter');
      expect(c.project.entities.whereType<PolylineEntity>().length, 2, reason: 'Esc dropped the points');
      final rect = tool(ToolId.rect);
      rect.onDown(const Pt(0, 0));
      rect.onMove(const Pt(4, 3));
      paint(rect);
      expect(host.status, '4.00 × 3.00 m');
      rect.onDown(const Pt(4, 3));
      final r = c.project.entities.whereType<PolylineEntity>().last;
      expect(r.closed, isTrue);
      expect(r.points, [Pt.zero, const Pt(4, 0), const Pt(4, 3), const Pt(0, 3)]);
    });

    test('circle, arc through three points and a straight arc', () {
      final circle = tool(ToolId.circle);
      circle.onDown(const Pt(1, 1));
      circle.onMove(const Pt(4, 5));
      paint(circle);
      expect(host.status, 'R = 5.00 m');
      circle.onDown(const Pt(4, 5));
      expect(only<CircleEntity>().radius, closeTo(5, 1e-12));
      final arc = tool(ToolId.arc);
      arc.onDown(const Pt(5, 0));
      arc.onDown(const Pt(0, 5));
      arc.onMove(const Pt(-5, 0));
      paint(arc);
      expect(host.status, startsWith('R = 5.00 m'));
      arc.onDown(const Pt(-5, 0));
      final a = only<ArcEntity>();
      expect(a.center.distanceTo(Pt.zero), lessThan(1e-9));
      expect(a.radius, closeTo(5, 1e-9));
      expect(a.sweepRad.abs(), closeTo(math.pi, 1e-9));
      clicks(tool(ToolId.arc), [const Pt(0, 10), const Pt(5, 10), const Pt(10, 10)]);
      expect(c.project.entities.whereType<PolylineEntity>().single.points.length, 3, reason: 'collinear points make a polyline');
    });

    test('spline and hatch follow the tool settings', () {
      c.toolSettings
        ..splineClosed = true
        ..hatchAngle = 30
        ..hatchSpacing = 0.5
        ..hatchSolid = true;
      final sp = tool(ToolId.spline);
      clicks(sp, [Pt.zero, const Pt(5, 5), const Pt(10, 0)]);
      sp.onMove(const Pt(12, 3));
      paint(sp);
      sp.onKey('Enter');
      expect(only<SplineEntity>().closed, isTrue);
      final h = tool(ToolId.hatch);
      clicks(h, [Pt.zero, const Pt(5, 0)]);
      h.onKey('Enter');
      expect(c.project.entities.whereType<HatchEntity>(), isEmpty, reason: 'a hatch needs three points');
      clicks(h, [Pt.zero, const Pt(5, 0), const Pt(5, 5)]);
      h.onKey('Enter');
      final hatch = only<HatchEntity>();
      expect(hatch.layer, Layers.hatches);
      expect((hatch.angleDeg, hatch.spacing, hatch.solid), (30, 0.5, true));
      c.setCurrentLayer(Layers.text);
      clicks(h, [const Pt(20, 0), const Pt(25, 0), const Pt(25, 5)]);
      h.onKey('Enter');
      expect(c.project.entities.whereType<HatchEntity>().last.layer, Layers.text, reason: 'a chosen layer wins');
    });

    test('linear, angular and radial dimensions', () {
      clicks(tool(ToolId.dimension), [Pt.zero, const Pt(10, 0), const Pt(4, 3)]);
      final d = only<DimensionEntity>();
      expect(d.offset, closeTo(3, 1e-9));
      final ang = tool(ToolId.dimAngular);
      clicks(ang, [Pt.zero, const Pt(10, 0), const Pt(0, 10)]);
      ang.onMove(const Pt(3, 3));
      paint(ang);
      expect(host.status, '90.0°');
      ang.onDown(const Pt(3, 3));
      final a1 = only<AngularDimensionEntity>();
      expect(a1.angleDeg, closeTo(90, 1e-9));
      expect(a1.radius, closeTo(math.sqrt(18), 1e-9));
      // the fourth click outside the 90° sector measures the other side
      clicks(tool(ToolId.dimAngular), [Pt.zero, const Pt(10, 0), const Pt(0, 10), const Pt(-3, -3)]);
      expect(c.project.entities.whereType<AngularDimensionEntity>().last.angleDeg, closeTo(270, 1e-9));
      final side = AngularDimensionTool.orientedAngularDimension('x', Pt.zero, const Pt(1, 0), const Pt(0, 1), const Pt(1, 1), 2);
      expect(side.a, const Pt(1, 0));
      // radial: a click on a circle takes its centre
      c.addEntity(CircleEntity(id: 'c1', center: const Pt(50, 50), radius: 4));
      c.addEntity(ArcEntity(id: 'a1', center: const Pt(80, 50), radius: 6, startRad: 0, sweepRad: 1));
      final rad = tool(ToolId.dimRadial);
      rad.onDown(const Pt(54, 50));
      rad.onMove(const Pt(50, 54));
      paint(rad);
      expect(host.status, 'R = 4.00 m');
      rad.onDown(const Pt(50, 54));
      final r1 = c.project.entities.whereType<RadialDimensionEntity>().single;
      expect(r1.center, const Pt(50, 50));
      expect(r1.radius, closeTo(4, 1e-9));
      final rad2 = tool(ToolId.dimRadial);
      rad2.onDown(const Pt(86, 50));
      rad2.onDown(const Pt(80, 56));
      expect(c.project.entities.whereType<RadialDimensionEntity>().last.center, const Pt(80, 50));
      final rad3 = tool(ToolId.dimRadial);
      rad3.onDown(const Pt(-100, -100));
      rad3.onDown(const Pt(-97, -96));
      expect(c.project.entities.whereType<RadialDimensionEntity>().last.radius, closeTo(5, 1e-9), reason: 'on empty ground the first click is the centre');
    });

    test('leader, block and sprinkler grid hand their points to the dialogs', () {
      final le = tool(ToolId.leader);
      clicks(le, [Pt.zero, const Pt(3, 3)]);
      le.onKey('Enter');
      expect(host.leader, [Pt.zero, const Pt(3, 3)]);
      for (final id in [ToolId.block, ToolId.autohead]) {
        final b = tool(id);
        clicks(b, [Pt.zero, const Pt(10, 0)]);
        b.onKey('Enter');
        expect(host.calls.where((x) => x == id.name), isEmpty, reason: '${id.name}: a polygon needs three points');
        clicks(b, [Pt.zero, const Pt(10, 0), const Pt(10, 10)]);
        b.onKey('Enter');
        expect(host.calls.last, id.name);
        expect(host.polygon!.length, 3);
      }
      expect(c.project.entities, isEmpty, reason: 'the dialogs create the entities');
    });

    test('contours: elevation prompt, automatic increment and smoothing', () {
      final ct = tool(ToolId.contour);
      clicks(ct, [Pt.zero, const Pt(10, 0)]);
      paint(ct);
      ct.onKey('Enter');
      expect(host.calls, ['elevation']);
      expect(host.elevationOf, isA<ContourEntity>());
      c.toolSettings
        ..askElevation = false
        ..contourAutoIncrement = true
        ..contourElevation = 100
        ..contourInterval = 2.5
        ..contourSmooth = true;
      clicks(ct, [const Pt(0, 10), const Pt(10, 12), const Pt(20, 10)]);
      ct.onKey('Enter');
      final smooth = c.project.entities.whereType<ContourEntity>().last;
      expect(smooth.elevation, 100);
      expect(smooth.points.length, greaterThan(3), reason: 'smoothed through the clicks');
      expect(c.toolSettings.contourElevation, 102.5);
      c.toolSettings.contourAutoIncrement = false;
      clicks(ct, [const Pt(0, 20), const Pt(10, 20)]);
      ct.onKey('Enter');
      expect(c.toolSettings.contourElevation, 102.5);
      expect(host.calls, ['elevation']);
    });

    test('area, pipes, laterals and tapes use the tool settings', () {
      final ar = tool(ToolId.area);
      clicks(ar, [Pt.zero, const Pt(10, 0), const Pt(10, 10)]);
      ar.onKey('Enter');
      expect(only<AreaEntity>().name, 'Área 1');
      clicks(tool(ToolId.zonePipe), [Pt.zero, const Pt(10, 0)]);
      tool(ToolId.zonePipe).onKey('Enter');
      final zp = tool(ToolId.zonePipe);
      clicks(zp, [Pt.zero, const Pt(10, 0)]);
      zp.onKey('Enter');
      final zone = only<PipeEntity>();
      expect(zone.scope, HydraulicScope.zone);
      expect(zone.computerSized, isTrue);
      expect(zone.pipeSpecId, isNull);
      c.toolSettings.mainPipeSpecId = 'pvc75';
      final mp = tool(ToolId.mainPipe);
      clicks(mp, [const Pt(0, 5), const Pt(10, 5)]);
      mp.onKey('Enter');
      final main = c.project.entities.whereType<PipeEntity>().last;
      expect(main.scope, HydraulicScope.mainline);
      expect(main.pipeSpecId, 'pvc75');
      expect(main.computerSized, isFalse);
      c.toolSettings
        ..spacing = 3
        ..outletOffsetHalf = true
        ..headM = 18
        ..tapeInletHeadM = 9;
      final sl = tool(ToolId.sprayline);
      clicks(sl, [const Pt(0, 20), const Pt(30, 20)]);
      sl.onKey('Enter');
      final lat = only<SpraylineEntity>();
      expect((lat.spacing, lat.offset, lat.headM, lat.outletSpecId), (3, 1.5, 18, 'micro'));
      final tp = tool(ToolId.tape);
      clicks(tp, [const Pt(0, 25), const Pt(30, 25)]);
      tp.onKey('Enter');
      final tape = only<TapeEntity>();
      expect((tape.tapeSpecId, tape.inletHeadM), (c.toolSettings.tapeSpecId, 9));
    });

    test('measure reports the distance and the direction; the profile tool sets and clears the path', () {
      clicks(tool(ToolId.measure), [Pt.zero, const Pt(3, 4)]);
      expect(host.status, 'Δ = 5.000 m  (Δx 3.00, Δy 4.00, 53.1°)');
      expect(c.project.entities, isEmpty);
      final pr = tool(ToolId.profile);
      clicks(pr, [Pt.zero, const Pt(50, 0)]);
      pr.onKey('Enter');
      expect(c.profilePath, [Pt.zero, const Pt(50, 0)]);
      pr.onKey('Escape');
      expect(c.profilePath, isNull);
    });

    test('pivots and linear machines from two clicks', () {
      final pv = tool(ToolId.pivot);
      pv.onMove(Pt.zero);
      paint(pv);
      pv.onDown(Pt.zero);
      pv.onMove(const Pt(0, 120));
      paint(pv);
      expect(host.status, startsWith('R = 120.00 m'));
      expect(host.status, endsWith(' 2'), reason: '120 m / 50 m spans');
      pv.onDown(const Pt(0, 120));
      final p1 = only<PivotEntity>();
      expect(p1.radiusM, closeTo(120, 1e-9));
      expect(p1.angleDeg, closeTo(90, 1e-9));
      c.toolSettings
        ..pivotKind = PivotKind.linear
        ..pivotTravelM = 300;
      final lin = tool(ToolId.pivot);
      lin.onDown(const Pt(500, 0));
      lin.onMove(const Pt(600, 0));
      paint(lin);
      lin.onDown(const Pt(600, 0));
      final p2 = c.project.entities.whereType<PivotEntity>().last;
      expect(p2.kind, PivotKind.linear);
      expect(p2.travelM, 300);
    });
  });

  group('editing tools', () {
    test('rotate, scale and mirror pick first, then transform with a preview', () {
      c.addEntity(LineEntity(id: 'l', a: Pt.zero, b: const Pt(10, 0)));
      final ro = tool(ToolId.rotate);
      ro.onDown(const Pt(5, 0.1));
      expect(c.selection, {'l'}, reason: 'with nothing selected a click picks');
      ro.onDown(Pt.zero);
      ro.onDown(const Pt(10, 0));
      expect(ro.referencePoint, Pt.zero);
      ro.onMove(const Pt(0, 10));
      paint(ro);
      expect(host.status, '90.00°');
      ro.onKey('Backspace');
      ro.onDown(const Pt(10, 0));
      ro.onDown(const Pt(0, 10));
      final l = c.project.byId('l') as LineEntity;
      expect(l.b.x, closeTo(0, 1e-9));
      expect(l.b.y, closeTo(10, 1e-9));
      final sc = tool(ToolId.scale);
      sc.onDown(Pt.zero);
      sc.onDown(const Pt(0, 1));
      sc.onMove(const Pt(0, 2));
      paint(sc);
      expect(host.status, '× 2.000');
      sc.onDown(const Pt(0, 2));
      expect((c.project.byId('l') as LineEntity).b.y, closeTo(20, 1e-9));
      final n = c.historyEntries.length;
      clicks(sc, [Pt.zero, const Pt(0, 1), const Pt(0, 1)]);
      expect(c.historyEntries.length, n, reason: 'a factor of 1 changes nothing');
      sc.onKey('Escape');
      final mi = tool(ToolId.mirror);
      mi.onDown(const Pt(-5, 0));
      mi.onMove(const Pt(5, 0));
      paint(mi);
      mi.onDown(const Pt(5, 0));
      expect(c.project.entities.whereType<LineEntity>().length, 2, reason: 'the source is kept');
      expect(c.project.entities.whereType<LineEntity>().any((e) => (e.b.y + 20).abs() < 1e-9), isTrue);
      // Ctrl makes a copy with rotate too
      c.select(['l']);
      clicks(ro, [Pt.zero, const Pt(0, 1)]);
      ro.onDown(const Pt(1, 0), ctrl: true);
      expect(c.project.entities.whereType<LineEntity>().length, 3);
    });

    test('offset picks a line or circle and copies it to the clicked side', () {
      c.addEntity(LineEntity(id: 'l', a: Pt.zero, b: const Pt(10, 0)));
      c.addEntity(CircleEntity(id: 'c', center: const Pt(50, 0), radius: 5));
      c.toolSettings.offsetDistance = 2;
      final off = tool(ToolId.offset);
      off.onDown(const Pt(-50, -50));
      expect(c.selection, isEmpty);
      off.onDown(const Pt(5, 0.1));
      expect(c.selection, {'l'});
      off.onMove(const Pt(5, -3));
      paint(off);
      expect(host.status, contains('2.00 m'));
      off.onDown(const Pt(5, -3));
      final copy = c.project.entities.whereType<LineEntity>().last;
      expect(copy.a.y, closeTo(-2, 1e-9));
      off.onDown(const Pt(55, 0.1));
      off.onMove(const Pt(50, 1));
      paint(off);
      off.onKey('Escape');
      off.onDown(const Pt(55, 0.1));
      off.onDown(const Pt(50, 1));
      expect(c.project.entities.whereType<CircleEntity>().map((e) => e.radius), containsAll([5.0, 3.0]), reason: 'clicked inside: smaller');
    });

    test('trim, extend (Shift picks edges) and cut pipe', () {
      c.addEntity(LineEntity(id: 'h', a: Pt.zero, b: const Pt(10, 0)));
      c.addEntity(LineEntity(id: 'v', a: const Pt(5, -5), b: const Pt(5, 5)));
      final tr = tool(ToolId.trim);
      tr.onDown(const Pt(5, 3), shift: true);
      expect(c.selection, {'v'});
      tr.onDown(const Pt(5, 3), shift: true);
      expect(c.selection, isEmpty);
      tr.onDown(const Pt(8, 0));
      expect((c.project.byId('h') as LineEntity).b.x, closeTo(5, 1e-9));
      c.addEntity(LineEntity(id: 'lonely', a: const Pt(0, 30), b: const Pt(10, 30)));
      tr.onDown(const Pt(5, 30));
      expect(c.lastMessage, 'Nenhuma interseção encontrada');
      tr.onDown(const Pt(500, 500));
      final ex = tool(ToolId.extend);
      c.addEntity(LineEntity(id: 'w', a: const Pt(9, -5), b: const Pt(9, 5)));
      ex.onDown(const Pt(4.9, 0));
      expect((c.project.byId('h') as LineEntity).b.x, closeTo(9, 1e-9));
      ex.onDown(const Pt(9, 4), shift: true);
      expect(c.selection, {'w'});
      ex.onDown(const Pt(9.5, 30));
      expect(c.lastMessage, 'Nenhuma interseção encontrada');
      c.addEntity(PipeEntity(id: 'p', points: [const Pt(0, 50), const Pt(20, 50)], scope: HydraulicScope.zone));
      final cut = tool(ToolId.cutPipe);
      cut.onMove(const Pt(8, 50));
      paint(cut);
      cut.onDown(const Pt(8, 50));
      expect(c.project.entities.whereType<PipeEntity>().length, 2);
      expect(c.lastMessage, 'Tubo cortado em 2 trechos');
      cut.onDown(const Pt(500, 500));
    });

    test('align maps two point pairs, or asks for a selection first', () {
      final al = tool(ToolId.alignImage);
      paint(al);
      expect(host.status, I18n('pt')('align.step1'));
      c.setTool(ToolId.alignImage);
      al.onDown(Pt.zero);
      expect(c.lastMessage, I18n('pt')('msg.alignSelectFirst'));
      expect(c.activeTool, ToolId.select);
      c.addEntity(LineEntity(id: 'l', a: Pt.zero, b: const Pt(10, 0)));
      c.select(['l']);
      c.setTool(ToolId.alignImage);
      final al2 = tool(ToolId.alignImage);
      al2.onDown(Pt.zero);
      expect(al2.referencePoint, Pt.zero);
      al2.onDown(const Pt(100, 100));
      al2.onKey('Backspace');
      al2.onDown(const Pt(100, 100));
      al2.onDown(const Pt(10, 0));
      al2.onMove(const Pt(100, 120));
      paint(al2);
      al2.onDown(const Pt(100, 120));
      final l = c.project.byId('l') as LineEntity;
      expect(l.a.distanceTo(const Pt(100, 100)), lessThan(1e-9));
      expect(l.b.distanceTo(const Pt(100, 120)), lessThan(1e-9));
      expect(c.lastMessage, contains('×2.000'));
      expect(c.activeTool, ToolId.select);
    });
  });

  group('item tools', () {
    test('text opens its dialog; symbols, spot heights and outlets are placed', () {
      tool(ToolId.text).onDown(const Pt(3, 3));
      expect(host.textAt, const Pt(3, 3));
      c.toolSettings
        ..symbolKind = SymbolKind.northArrow
        ..symbolSize = 4;
      final sy = tool(ToolId.symbol);
      sy.onMove(Pt.zero);
      paint(sy);
      sy.onDown(Pt.zero);
      final s = only<SymbolEntity>();
      expect((s.kind, s.size, s.layer), (SymbolKind.northArrow, 4, Layers.symbols));
      c.toolSettings.spotElevation = 512;
      tool(ToolId.spot).onDown(const Pt(1, 1));
      expect(only<SpotHeightEntity>().elevation, 512);
      expect(host.calls.last, 'elevation');
      c.toolSettings.askElevation = false;
      tool(ToolId.spot).onDown(const Pt(2, 2));
      expect(host.calls.where((x) => x == 'elevation').length, 1);
      c.toolSettings
        ..headM = 21
        ..arcDeg = 180;
      tool(ToolId.outlet).onDown(const Pt(5, 5));
      final o = only<OutletEntity>();
      expect((o.headM, o.arcDeg, o.scope), (21, 180, HydraulicScope.zone));
    });

    test('valves, pumps, fittings and junctions split the pipe under them', () {
      c.addEntity(PipeEntity(id: 'z', points: [Pt.zero, const Pt(40, 0)], scope: HydraulicScope.zone));
      c.addEntity(PipeEntity(id: 'm', points: [const Pt(0, 20), const Pt(40, 20)], scope: HydraulicScope.mainline));
      tool(ToolId.valve).onDown(const Pt(10, 0));
      final v = only<ControlValveEntity>();
      expect(v.zoneName, 'Zona 1');
      expect(v.valveSpecId, 'ev50');
      tool(ToolId.valve).onDown(const Pt(100, 100));
      expect(c.project.entities.whereType<ControlValveEntity>().last.zoneName, 'Zona 2');
      expect(c.project.entities.whereType<PipeEntity>().where((p) => p.scope == HydraulicScope.zone).length, 2);
      c.toolSettings.pointScope = HydraulicScope.mainline;
      tool(ToolId.pump).onDown(const Pt(10, 20));
      final pump = only<PumpEntity>();
      expect(pump.scope, HydraulicScope.mainline);
      expect(pump.pumpSpecId, 'pump_mid');
      tool(ToolId.misc).onDown(const Pt(20, 20));
      final misc = only<MiscHydraulicEntity>();
      expect((misc.valveSpecId, misc.settingM, misc.scope), ('gate50', 25, HydraulicScope.mainline));
      tool(ToolId.junction).onDown(const Pt(30, 20));
      expect(only<JunctionEntity>().scope, HydraulicScope.mainline);
      expect(c.project.entities.whereType<PipeEntity>().where((p) => p.scope == HydraulicScope.mainline).length, 4, reason: 'three items, four pieces');
      final sup = tool(ToolId.supply);
      sup.onMove(Pt.zero);
      paint(sup);
      sup.onDown(const Pt(0, 20));
      tool(ToolId.supply).onDown(const Pt(-50, 20));
      expect(c.project.entities.whereType<WaterSupplyEntity>().map((s) => s.name), ['Fonte 1', 'Fonte 2']);
    });
  });

  group('select tool', () {
    test('Shift toggles, a drag on empty ground selects by window or crossing, Esc clears', () {
      c.addEntities([
        LineEntity(id: 'a', a: Pt.zero, b: const Pt(10, 0)),
        LineEntity(id: 'b', a: const Pt(20, 0), b: const Pt(40, 0)),
      ]);
      final s = tool(ToolId.select);
      s.onDown(const Pt(5, 0.1));
      s.onUp(const Pt(5, 0.1));
      expect(c.selection, {'a'});
      s.onDown(const Pt(30, 0.1), shift: true);
      s.onUp(const Pt(30, 0.1));
      expect(c.selection, {'a', 'b'});
      s.onDown(const Pt(5, 0.1), shift: true);
      s.onUp(const Pt(5, 0.1));
      expect(c.selection, {'b'});
      s.onKey('Escape');
      expect(c.selection, isEmpty);
      // window (left to right): only what is fully inside
      s.onDown(const Pt(-1, -5));
      s.onMove(const Pt(25, 5), dragging: true);
      paint(s);
      s.onUp(const Pt(25, 5));
      expect(c.selection, {'a'});
      // crossing (right to left): what it touches
      s.onDown(const Pt(25, 5));
      s.onMove(const Pt(-1, -5), dragging: true);
      paint(s);
      s.onUp(const Pt(-1, -5));
      expect(c.selection, {'a', 'b'});
    });

    test('Ctrl on a vertex grip removes the vertex; dragging a grip paints its coordinates', () {
      c.addEntity(PolylineEntity(id: 'p', points: [Pt.zero, const Pt(10, 0), const Pt(10, 10)]));
      c.select(['p']);
      final s = tool(ToolId.select);
      expect((s as SelectTool).grips().where((g) => !g.midpoint).length, 3);
      s.onDown(const Pt(10, 0), ctrl: true);
      expect((c.project.byId('p') as PolylineEntity).points, [Pt.zero, const Pt(10, 10)]);
      c.select(['p']);
      s.onDown(const Pt(10, 10), ctrl: true);
      expect((c.project.byId('p') as PolylineEntity).points.length, 2, reason: 'a two-point polyline keeps its vertices');
      c.select(['p']);
      s.onDown(const Pt(10, 10));
      s.onMove(const Pt(12, 14), dragging: true);
      paint(s);
      expect(host.status, 'X 12.00 m  Y 14.00 m');
      s.onUp(const Pt(12, 14));
      expect((c.project.byId('p') as PolylineEntity).points.last, const Pt(12, 14));
      // a moved line previews its ghost
      c.addEntity(LineEntity(id: 'l', a: const Pt(0, 30), b: const Pt(10, 30)));
      s.onDown(const Pt(5, 30.1));
      s.onMove(const Pt(5, 35), dragging: true);
      paint(s);
      s.onUp(const Pt(5, 35));
      expect((c.project.byId('l') as LineEntity).a.y, closeTo(34.9, 1e-9));
    });
  });
}
