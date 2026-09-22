import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/model/currency.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/split.dart';

void main() {
  group('affine transforms', () {
    test('rotation, mirror and scale map points and angles', () {
      final r = Affine.rotation(math.pi / 2, const Pt(1, 1));
      final p = r.apply(const Pt(2, 1));
      expect(p.x, closeTo(1, 1e-9));
      expect(p.y, closeTo(2, 1e-9));
      expect(r.scale, closeTo(1, 1e-12));
      expect(r.isMirror, isFalse);
      final m = Affine.mirror(const Pt(0, 0), const Pt(0, 1));
      final q = m.apply(const Pt(3, 2));
      expect(q.x, closeTo(-3, 1e-9));
      expect(q.y, closeTo(2, 1e-9));
      expect(m.isMirror, isTrue);
      final s = Affine.scaling(2, const Pt(1, 1));
      final w = s.apply(const Pt(2, 3));
      expect(w.x, closeTo(3, 1e-9));
      expect(w.y, closeTo(5, 1e-9));
      expect(s.scale, closeTo(2, 1e-12));
      expect(radToDeg(r.transformAngle(0)), closeTo(90, 1e-9));
    });

    test('entities keep their semantics under transforms', () {
      final arc = ArcEntity(id: 'a', center: Pt.zero, radius: 2, startRad: 0, sweepRad: math.pi / 2);
      final mirrored = arc.transformed(Affine.mirror(Pt.zero, const Pt(0, 1)));
      expect(mirrored.sweepRad, closeTo(-math.pi / 2, 1e-9));
      expect(mirrored.startPoint.x, closeTo(-2, 1e-9));
      final text = TextEntity(id: 't', position: const Pt(1, 0), text: 'x', rotationDeg: 10);
      final rt = text.transformed(Affine.rotation(math.pi / 2));
      expect(rt.rotationDeg, closeTo(100, 1e-9));
      final sp = SpraylineEntity(id: 's', points: [Pt.zero, const Pt(10, 0)], outletSpecId: 'micro', spacing: 2, offset: 1);
      final ss = sp.transformed(Affine.scaling(2));
      expect(ss.spacing, closeTo(4, 1e-9));
      expect(ss.outletCount, sp.outletCount);
      final dim = DimensionEntity(id: 'd', a: Pt.zero, b: const Pt(4, 0), offset: 1);
      final dm = dim.transformed(Affine.mirror(Pt.zero, const Pt(1, 0)));
      // mirrored about the x axis: the dimension line must stay on the mirrored side
      expect((dm.a + dm.normal * dm.offset).y, closeTo(-1, 1e-9));
      final img = ImageEntity(id: 'i', origin: Pt.zero, width: 4, height: 2);
      final ir = img.transformed(Affine.rotation(math.pi / 2));
      expect(ir.rotationDeg, closeTo(90, 1e-9));
      expect(ir.corners[2].x, closeTo(-2, 1e-9));
    });

    test('grips edit vertices, circles and arcs', () {
      final pl = PolylineEntity(id: 'p', points: [Pt.zero, const Pt(5, 0), const Pt(5, 5)]);
      pl.setGrip(1, const Pt(6, 1));
      expect(pl.points[1], const Pt(6, 1));
      pl.insertVertex(1, const Pt(3, 0));
      expect(pl.points.length, 4);
      pl.removeVertex(1);
      expect(pl.points.length, 3);
      final c = CircleEntity(id: 'c', center: Pt.zero, radius: 1);
      c.setGrip(1, const Pt(3, 4));
      expect(c.radius, closeTo(5, 1e-9));
      final a = ArcEntity(id: 'a', center: Pt.zero, radius: 2, startRad: 0, sweepRad: math.pi / 2);
      final end = a.endPoint;
      a.setGrip(2, const Pt(-2, 0)); // move the end to 180°
      expect(a.sweepRad, closeTo(math.pi, 1e-6));
      expect(a.endPoint.distanceTo(const Pt(-2, 0)), lessThan(1e-6));
      expect(end.distanceTo(const Pt(0, 2)), lessThan(1e-9));
    });
  });

  group('splitting, trimming, extending, offsetting', () {
    test('split keeps sprayline outlets in place', () {
      final s = SpraylineEntity(id: 's', points: [Pt.zero, const Pt(20, 0)], outletSpecId: 'micro', spacing: 4, offset: 2);
      final before = s.outletPositions();
      var seq = 0;
      final pieces = splitLinearEntity(s, [7], () => 'n${seq++}');
      expect(pieces.length, 2);
      final after = [for (final p in pieces) ...(p as SpraylineEntity).outletPositions()];
      expect(after.length, before.length);
      for (var i = 0; i < before.length; i++) {
        expect(after[i].distanceTo(before[i]), lessThan(1e-9));
      }
      expect(pieces.first.id, 's');
    });

    test('trim removes the clicked portion between two crossings', () {
      final line = LineEntity(id: 'l', a: Pt.zero, b: const Pt(10, 0));
      var seq = 0;
      final pieces = trimLinearEntity(line, 5, [3, 7], () => 'n${seq++}');
      expect(pieces.length, 2);
      expect((pieces[0] as LineEntity).b.x, closeTo(3, 1e-9));
      expect((pieces[1] as LineEntity).a.x, closeTo(7, 1e-9));
      // trimming the tail beyond the only cut removes it
      final tail = trimLinearEntity(LineEntity(id: 'l2', a: Pt.zero, b: const Pt(10, 0)), 9, [4], () => 'x');
      expect(tail.length, 1);
      expect((tail.first as LineEntity).b.x, closeTo(4, 1e-9));
    });

    test('extend reaches the next boundary; offset keeps distance', () {
      final line = LineEntity(id: 'l', a: Pt.zero, b: const Pt(5, 0));
      final ok = extendLinearEntity(line, const Pt(5, 0), [[const Pt(8, -5), const Pt(8, 5)]]);
      expect(ok, isTrue);
      expect(line.b.x, closeTo(8, 1e-9));
      final off = offsetEntity(PolylineEntity(id: 'p', points: [Pt.zero, const Pt(10, 0), const Pt(10, 10)]), 1, 'o') as PolylineEntity;
      expect(off.points.first.y, closeTo(1, 1e-9));
      expect(off.points[1].x, closeTo(9, 1e-9));
      expect(off.points[1].y, closeTo(1, 1e-9));
      final circle = offsetEntity(CircleEntity(id: 'c', center: Pt.zero, radius: 3), -1, 'c2') as CircleEntity;
      expect(circle.radius, closeTo(2, 1e-9));
    });
  });

  group('controller editing', () {
    ProjectController fresh() {
      setPref('lang', 'pt');
      final c = ProjectController();
      c.autosaveEnabled = false;
      c.newProject();
      return c;
    }

    test('rotate, mirror, scale, array and undo with cloned states', () {
      final c = fresh();
      c.addEntity(LineEntity(id: 'l1', a: Pt.zero, b: const Pt(10, 0)));
      c.select(['l1']);
      c.rotateSelected(Pt.zero, math.pi / 2);
      final l = c.project.byId('l1') as LineEntity;
      expect(l.b.y, closeTo(10, 1e-9));
      c.mirrorSelected(Pt.zero, const Pt(1, 0), keepSource: true);
      expect(c.project.entities.length, 2);
      expect(c.selection.length, 1);
      expect(c.selection.first, isNot('l1'));
      c.select(['l1']);
      c.scaleSelected(Pt.zero, 0.5);
      expect((c.project.byId('l1') as LineEntity).b.y, closeTo(5, 1e-9));
      final n = c.arraySelected(ArrayOptions(rows: 2, cols: 3, dx: 2, dy: 2));
      expect(n, 5);
      expect(c.project.entities.length, 7);
      c.undo();
      expect(c.project.entities.length, 2);
      c.undo();
      expect((c.project.byId('l1') as LineEntity).b.y, closeTo(10, 1e-9));
      c.redo();
      expect((c.project.byId('l1') as LineEntity).b.y, closeTo(5, 1e-9));
      c.select(['l1']);
      final polar = c.arraySelected(ArrayOptions(polar: true, count: 4, center: Pt.zero, totalAngleDeg: 360));
      expect(polar, 3);
    });

    test('cut pipe and inserting a valve split the pipe at the point', () {
      final c = fresh();
      c.addEntity(PipeEntity(id: 'p', points: [Pt.zero, const Pt(20, 0)], scope: HydraulicScope.zone));
      expect(c.cutAt('p', const Pt(8, 0.01)), isTrue);
      expect(c.project.entities.whereType<PipeEntity>().length, 2);
      final v = ControlValveEntity(id: 'v', position: const Pt(4, 0), zoneName: 'Z');
      c.addPointItem(v, const Pt(4, 0));
      final pipes = c.project.entities.whereType<PipeEntity>().toList();
      expect(pipes.length, 3);
      // the pieces run 0–4, 4–8 and 8–20 along the axis (the cut point is
      // projected onto the pipe), and the valve sits on a shared vertex
      final spans = [for (final p in pipes) (math.min(p.points.first.x, p.points.last.x), math.max(p.points.first.x, p.points.last.x))]..sort((a, b) => a.$1.compareTo(b.$1));
      for (final (i, want) in [(0.0, 4.0), (4.0, 8.0), (8.0, 20.0)].indexed) {
        expect(spans[i].$1, closeTo(want.$1, 1e-6), reason: 'piece $i start');
        expect(spans[i].$2, closeTo(want.$2, 1e-6), reason: 'piece $i end');
      }
      expect(pipes.every((p) => p.points.every((q) => q.y.abs() < 1e-9)), isTrue);
      expect(pipes.where((p) => p.points.first.distanceTo(v.position) < 1e-9 || p.points.last.distanceTo(v.position) < 1e-9).length, 2);
    });

    test('trim/extend through the controller use crossing entities', () {
      final c = fresh();
      c.addEntity(LineEntity(id: 'h', a: const Pt(0, 0), b: const Pt(10, 0)));
      c.addEntity(LineEntity(id: 'v', a: const Pt(5, -5), b: const Pt(5, 5)));
      expect(c.trimAt('h', const Pt(8, 0)), isTrue);
      final h = c.project.byId('h') as LineEntity;
      expect(h.b.x, closeTo(5, 1e-9));
      c.addEntity(LineEntity(id: 'w', a: const Pt(9, -5), b: const Pt(9, 5)));
      expect(c.extendAt('h', const Pt(5, 0)), isTrue);
      expect((c.project.byId('h') as LineEntity).b.x, closeTo(9, 1e-9));
      final off = c.offsetEntityTo('h', 2, const Pt(3, 3));
      expect(off, isNotNull);
      expect((off as LineEntity).a.y, closeTo(2, 1e-9));
    });

    test('locked layers block edits and picking; layer management', () {
      final c = fresh();
      c.addEntity(LineEntity(id: 'l', a: Pt.zero, b: const Pt(10, 0)));
      c.setLayerLocked(Layers.drawing, true);
      expect(c.pick(const Pt(5, 0), 1), isNull);
      c.select(['l']);
      c.moveSelected(const Pt(1, 1));
      expect((c.project.byId('l') as LineEntity).a, Pt.zero);
      c.setLayerLocked(Layers.drawing, false);
      expect(c.addLayer('MEU'), isTrue);
      expect(c.addLayer('MEU'), isFalse);
      c.setCurrentLayer('MEU');
      c.addEntity(LineEntity(id: 'm', layer: c.drawingLayer, a: Pt.zero, b: const Pt(1, 1)));
      expect(c.project.byId('m')!.layer, 'MEU');
      expect(c.renameLayer('MEU', 'NOVO'), isTrue);
      expect(c.project.byId('m')!.layer, 'NOVO');
      c.removeLayer('NOVO');
      expect(c.project.byId('m')!.layer, Layers.drawing);
      c.setLayerColor(Layers.drawing, 0xFF112233);
      expect(c.project.layerNamed(Layers.drawing).color, 0xFF112233);
    });

    test('batch edit applies to every selected entity of the type', () {
      final c = fresh();
      for (var i = 0; i < 3; i++) {
        c.addEntity(SpraylineEntity(id: 's$i', points: [Pt(0, i * 4.0), Pt(20, i * 4.0)], outletSpecId: 'micro', headM: 15, spacing: 4));
      }
      c.select(['s0', 's1', 's2']);
      final n = c.mutateSelected<SpraylineEntity>((e) => e.headM = 20);
      expect(n, 3);
      expect(c.project.entities.whereType<SpraylineEntity>().every((e) => e.headM == 20), isTrue);
    });

    test('results are persisted in the project JSON and restored', () async {
      final c = fresh();
      loadExampleAction(c);
      await c.runDesign();
      expect(c.results, isNotNull);
      final json = c.saveJson();
      expect(json, contains('"results"'));
      final d = ProjectController()..autosaveEnabled = false;
      d.loadJson(json);
      expect(d.results, isNotNull);
      expect(d.results!.zones.length, c.results!.zones.length);
      expect(d.results!.bom.length, c.results!.bom.length);
      expect(d.results!.flushing.length, c.results!.flushing.length);
      expect(d.results!.surge.length, c.results!.surge.length);
      expect(d.results!.capitalCost, closeTo(c.results!.capitalCost, 1e-6));
      expect(d.reportTables().any((t) => t.key == 'zones'), isTrue);
      expect(d.project.meta.uid, c.project.meta.uid);
    });

    test('autosave and version history in the local store', () {
      final store = LocalProjectStore();
      store.clearAll();
      final c = ProjectController(store: store);
      c.newProject();
      c.project.meta.name = 'Auto';
      c.addEntity(LineEntity(id: 'l', a: Pt.zero, b: const Pt(1, 0)));
      c.autosaveNow();
      expect(store.recoverable().length, 1);
      expect(store.load(c.project.meta.uid), isNotNull);
      c.saveJson();
      expect(store.recoverable(), isEmpty);
      expect(store.versions(c.project.meta.uid).length, 1);
      c.addEntity(LineEntity(id: 'l2', a: Pt.zero, b: const Pt(2, 0)));
      c.saveJson();
      expect(store.versions(c.project.meta.uid).length, 2);
      final v1 = store.load(c.project.meta.uid, version: 1)!;
      final d = ProjectController(store: store)..loadJson(v1);
      expect(d.project.entities.length, 1);
      store.remove(c.project.meta.uid);
      expect(store.list(), isEmpty);
    });

    test('feed envelope and terrain profile are computed for laterals', () {
      final c = fresh();
      c.addEntity(ContourEntity(id: 'c1', points: [const Pt(-10, -10), const Pt(-10, 10)], elevation: 100));
      c.addEntity(ContourEntity(id: 'c2', points: [const Pt(60, -10), const Pt(60, 10)], elevation: 103));
      c.addEntity(SpraylineEntity(id: 's', points: [Pt.zero, const Pt(50, 0)], outletSpecId: 'micro', nozzleId: 'm50', headM: 15, spacing: 4, offset: 2, pipeSpecId: 'pe25'));
      c.select(['s']);
      expect(c.computeFeedEnvelope(), 1);
      final res = c.feedEnvelope['s']!;
      expect(res.length, 21);
      final prof = c.profileAlong([Pt.zero, const Pt(50, 0)]);
      expect(prof.first.$2, lessThan(prof.last.$2));
    });

    test('new project uses the saved default catalog, converted to the project currency', () {
      setPref('lang', 'pt');
      setPref('currency', 'BRL');
      try {
        final c = ProjectController()..autosaveEnabled = false;
        c.newProject();
        expect(c.project.params.currencyCode, 'BRL');
        final keep = c.project.catalog.pipes.first;
        c.project.catalog.pipes.removeRange(1, c.project.catalog.pipes.length);
        c.saveDefaultCatalog();
        expect(getPref('catalog.default.currency'), 'BRL');
        c.newProject();
        expect(c.project.catalog.pipes.map((p) => p.id), [keep.id], reason: 'the saved list, not the built-in one');
        expect(c.project.catalog.pipes.single.costPerM, closeTo(keep.costPerM, 1e-9));
        // another currency gets the saved prices converted
        expect(c.defaultCatalog('USD').pipes.single.costPerM, closeTo(keep.costPerM * exchangeRate('BRL', 'USD')!, 1e-9));
        // saves made before the currency was recorded were in reais
        removePref('catalog.default.currency');
        expect(c.defaultCatalog('EUR').pipes.single.costPerM, closeTo(keep.costPerM * exchangeRate('BRL', 'EUR')!, 1e-9));
        // text that is not a catalogue falls back to the built-in one
        setPref('catalog.default', '{pipes: [not json]}');
        c.newProject();
        expect(c.project.catalog.pipes.length, greaterThan(1));
        c.saveDefaultCatalog();
        c.clearDefaultCatalog();
        expect(getPref('catalog.default'), isNull);
        expect(getPref('catalog.default.currency'), isNull);
      } finally {
        removePref('catalog.default');
        removePref('catalog.default.currency');
        removePref('currency');
      }
    });
  });

  test('project JSON round trip keeps the new entities', () {
    final p = Project();
    p.entities.addAll([
      SplineEntity(id: 'sp', points: [Pt.zero, const Pt(5, 5), const Pt(10, 0)]),
      HatchEntity(id: 'h', points: [Pt.zero, const Pt(10, 0), const Pt(10, 10)], angleDeg: 30, spacing: 0.5),
      SymbolEntity(id: 'sy', position: const Pt(1, 1), kind: SymbolKind.northArrow, size: 3),
      AngularDimensionEntity(id: 'ad', vertex: Pt.zero, a: const Pt(1, 0), b: const Pt(0, 1), radius: 2),
      RadialDimensionEntity(id: 'rd', center: Pt.zero, point: const Pt(3, 4)),
      LeaderEntity(id: 'le', points: [Pt.zero, const Pt(2, 2)], text: 'note'),
      ImageEntity(id: 'im', origin: Pt.zero, width: 4, height: 2, mime: 'image/png', source: 'x.png'),
      AreaEntity(id: 'ar', points: [Pt.zero, const Pt(10, 0), const Pt(10, 10)], useWaterBalance: true, kc: 0.8, emittersPerPlant: 2),
    ]);
    final q = Project.fromJsonString(p.toJsonString());
    expect(q.entities.length, p.entities.length);
    expect((q.byId('h') as HatchEntity).patternLines(), isNotEmpty);
    expect((q.byId('ad') as AngularDimensionEntity).angleDeg, closeTo(90, 1e-9));
    expect((q.byId('rd') as RadialDimensionEntity).radius, closeTo(5, 1e-9));
    expect((q.byId('ar') as AreaEntity).emittersPerPlant, 2);
    expect((q.byId('sy') as SymbolEntity).strokes(), isNotEmpty);
    expect(I18n('pt')('tool.spline'), isNot('tool.spline'));
  });
}
